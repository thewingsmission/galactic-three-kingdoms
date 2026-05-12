import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/soldier_design_catalog.dart';
import 'cohort_models.dart';
import 'soldier_design.dart';
import 'soldier_design_palette.dart';

/// Persistent app session data that survives screen changes.
///
/// Only lightweight cohort configuration lives here so screens themselves can
/// be popped and disposed without losing the player's formation setup.
class GameSessionState {
  static const int inventorySize = 44;

  static final List<SoldierDesign> roster =
      List<SoldierDesign>.unmodifiable(<SoldierDesign>[
        for (int i = 0; i < 10; i++) kProductionSoldierDesignCatalog[1],
        for (int i = 0; i < 10; i++) kProductionSoldierDesignCatalog[0],
        for (int i = 0; i < 8; i++) kProductionSoldierDesignCatalog[3],
        for (int i = 0; i < 8; i++) kProductionSoldierDesignCatalog[4],
        for (int i = 0; i < 8; i++) kProductionSoldierDesignCatalog[5],
      ]);

  SoldierDesignPalette palette = SoldierDesignPalette.yellow;
  List<bool> selected = List<bool>.filled(inventorySize, false);
  Map<int, Offset> offsets = <int, Offset>{};
  int? cohortLeaderIndex;
  final Map<String, Map<int, Map<int, int>>> cellScores =
      <String, Map<int, Map<int, int>>>{
        'red': <int, Map<int, int>>{},
        'yellow': <int, Map<int, int>>{},
        'blue': <int, Map<int, int>>{},
      };
  bool cellScoresLoaded = false;
  final List<KingdomScoreHistoryPoint> kingdomDailyScoreHistory =
      <KingdomScoreHistoryPoint>[];
  final List<KingdomScoreHistoryPoint> kingdomMonthlyScoreHistory =
      <KingdomScoreHistoryPoint>[];
  bool kingdomScoreHistoryLoaded = false;

  void saveInventoryState({
    required SoldierDesignPalette palette,
    required List<bool> selected,
    required Map<int, Offset> offsets,
    required int? cohortLeaderIndex,
  }) {
    this.palette = palette;
    this.selected = List<bool>.from(selected);
    this.offsets = Map<int, Offset>.from(offsets);
    this.cohortLeaderIndex = cohortLeaderIndex;
  }

  int get selectedCount => selected.where((bool value) => value).length;

  Future<void> loadCellScores() async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('scores')
            .doc('cell_scores')
            .get()
            .timeout(
              const Duration(seconds: 12),
              onTimeout: () {
                throw TimeoutException(
                  'Timed out loading Firestore document scores/cell_scores.',
                );
              },
            );
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      throw StateError('Firestore document scores/cell_scores does not exist.');
    }

    for (final String faction in cellScores.keys) {
      cellScores[faction]!.clear();
    }

    final RegExp fieldPattern = RegExp(
      r'^(-?\d+)_(-?\d+)_(red|yellow|blue)_score$',
    );
    for (final MapEntry<String, dynamic> entry in data.entries) {
      final RegExpMatch? match = fieldPattern.firstMatch(entry.key);
      if (match == null) {
        continue;
      }
      final int q = int.parse(match.group(1)!);
      final int r = int.parse(match.group(2)!);
      final String faction = match.group(3)!;
      final int value = (entry.value as num?)?.toInt() ?? 0;

      final Map<int, Map<int, int>> factionScores = cellScores[faction]!;
      final Map<int, int> qScores = factionScores.putIfAbsent(
        q,
        () => <int, int>{},
      );
      qScores[r] = value;
    }

    cellScoresLoaded = true;
  }

  Future<void> loadKingdomScoreHistory({bool forceRefresh = false}) async {
    if (kingdomScoreHistoryLoaded && !forceRefresh) {
      return;
    }

    final Future<DocumentSnapshot<Map<String, dynamic>>> dailyRequest =
        FirebaseFirestore.instance
            .collection('scores')
            .doc('kingdom_daily_score')
            .get();
    final Future<DocumentSnapshot<Map<String, dynamic>>> monthlyRequest =
        FirebaseFirestore.instance
            .collection('scores')
            .doc('kingdom_monthly_score')
            .get();

    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(<Future<DocumentSnapshot<Map<String, dynamic>>>>[
          dailyRequest,
          monthlyRequest,
        ]).timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            throw TimeoutException(
              'Timed out loading Firestore documents scores/kingdom_daily_score and scores/kingdom_monthly_score.',
            );
          },
        );

    final Map<String, dynamic>? dailyData = snapshots[0].data();
    final Map<String, dynamic>? monthlyData = snapshots[1].data();
    if (dailyData == null) {
      throw StateError(
        'Firestore document scores/kingdom_daily_score does not exist.',
      );
    }
    if (monthlyData == null) {
      throw StateError(
        'Firestore document scores/kingdom_monthly_score does not exist.',
      );
    }

    kingdomDailyScoreHistory
      ..clear()
      ..addAll(_parseKingdomScoreHistory(dailyData['days'], 'daily'));
    kingdomMonthlyScoreHistory
      ..clear()
      ..addAll(_parseKingdomScoreHistory(monthlyData['months'], 'monthly'));
    kingdomScoreHistoryLoaded = true;
  }

  List<KingdomScoreHistoryPoint> _parseKingdomScoreHistory(
    dynamic rawEntries,
    String granularity,
  ) {
    final Map<String, dynamic> entries = rawEntries is Map<String, dynamic>
        ? rawEntries
        : <String, dynamic>{};
    final List<String> orderedKeys = entries.keys.toList()..sort();
    return orderedKeys.map((String periodId) {
      final dynamic rawPoint = entries[periodId];
      final Map<String, dynamic> point = rawPoint is Map<String, dynamic>
          ? rawPoint
          : <String, dynamic>{};
      return KingdomScoreHistoryPoint(
        periodId: periodId,
        granularity: granularity,
        territorySizeByFaction: _parseKingdomMetricMap(point, 'territory_size'),
        landPowerByFaction: _parseKingdomMetricMap(point, 'land_power'),
        tributeRevenueByFaction: _parseKingdomMetricMap(
          point,
          'tribute_revenue',
        ),
      );
    }).toList();
  }

  Map<SoldierDesignPalette, int> _parseKingdomMetricMap(
    Map<String, dynamic> point,
    String metricKey,
  ) {
    return <SoldierDesignPalette, int>{
      for (final SoldierDesignPalette faction in SoldierDesignPalette.values)
        faction: _parseFactionMetric(point[_factionKey(faction)], metricKey),
    };
  }

  int _parseFactionMetric(dynamic rawFactionData, String metricKey) {
    if (rawFactionData is! Map) {
      return 0;
    }
    final dynamic metricValue = rawFactionData[metricKey];
    return (metricValue as num?)?.toInt() ?? 0;
  }

  int cellScore(String faction, int q, int r) =>
      cellScores[faction]?[q]?[r] ?? 0;

  int scoreForFaction(SoldierDesignPalette faction, int q, int r) =>
      cellScore(_factionKey(faction), q, r);

  Map<SoldierDesignPalette, int> scoresForCell(
    int q,
    int r,
  ) => <SoldierDesignPalette, int>{
    SoldierDesignPalette.red: scoreForFaction(SoldierDesignPalette.red, q, r),
    SoldierDesignPalette.yellow: scoreForFaction(
      SoldierDesignPalette.yellow,
      q,
      r,
    ),
    SoldierDesignPalette.blue: scoreForFaction(SoldierDesignPalette.blue, q, r),
  };

  SoldierDesignPalette? _specialFactionForCell(int q, int r) {
    for (final SoldierDesignPalette faction in SoldierDesignPalette.values) {
      if (scoreForFaction(faction, q, r) < 0) {
        return faction;
      }
    }
    return null;
  }

  SoldierDesignPalette ownerForCell(int q, int r) {
    final SoldierDesignPalette? specialFaction = _specialFactionForCell(q, r);
    if (specialFaction != null) {
      return specialFaction;
    }

    final int red = scoreForFaction(SoldierDesignPalette.red, q, r);
    final int yellow = scoreForFaction(SoldierDesignPalette.yellow, q, r);
    final int blue = scoreForFaction(SoldierDesignPalette.blue, q, r);

    if (red >= yellow && red >= blue) {
      return SoldierDesignPalette.red;
    }
    if (yellow >= red && yellow >= blue) {
      return SoldierDesignPalette.yellow;
    }
    return SoldierDesignPalette.blue;
  }

  int levelForCell(int q, int r) {
    if (_specialFactionForCell(q, r) != null) {
      return 5;
    }

    final Map<SoldierDesignPalette, int> scores = scoresForCell(q, r);
    final SoldierDesignPalette owner = ownerForCell(q, r);
    final int ownerScore = scores[owner] ?? 0;
    if (ownerScore <= 10000) {
      return 1;
    }

    final int combinedOtherScores = scores.entries
        .where(
          (MapEntry<SoldierDesignPalette, int> entry) => entry.key != owner,
        )
        .fold<int>(0, (int sum, MapEntry<SoldierDesignPalette, int> entry) {
          return sum + entry.value;
        });
    if (combinedOtherScores <= 0) {
      return 4;
    }

    final double ratio = ownerScore / combinedOtherScores;
    if (ratio <= 1) {
      return 1;
    }
    if (ratio <= 2) {
      return 2;
    }
    if (ratio <= 5) {
      return 3;
    }
    return 4;
  }

  Map<SoldierDesignPalette, int> ownedCellCounts() {
    final Set<(int, int)> coordinates = <(int, int)>{};
    for (final Map<int, Map<int, int>> factionScores in cellScores.values) {
      for (final MapEntry<int, Map<int, int>> qEntry in factionScores.entries) {
        for (final int r in qEntry.value.keys) {
          coordinates.add((qEntry.key, r));
        }
      }
    }

    final Map<SoldierDesignPalette, int> counts = <SoldierDesignPalette, int>{
      for (final SoldierDesignPalette faction in SoldierDesignPalette.values)
        faction: 0,
    };
    for (final (int q, int r) in coordinates) {
      final SoldierDesignPalette owner = ownerForCell(q, r);
      counts[owner] = (counts[owner] ?? 0) + 1;
    }
    return counts;
  }

  static String _factionKey(SoldierDesignPalette faction) => switch (faction) {
    SoldierDesignPalette.red => 'red',
    SoldierDesignPalette.yellow => 'yellow',
    SoldierDesignPalette.blue => 'blue',
  };

  CohortDeployment buildDeployment() {
    final List<PlacedSoldier> soldiers = <PlacedSoldier>[];
    final int? leader = cohortLeaderIndex;

    if (leader != null &&
        leader >= 0 &&
        leader < inventorySize &&
        selected[leader]) {
      soldiers.add(
        PlacedSoldier(
          inventoryIndex: leader,
          type: SoldierType.triangle,
          localOffset: offsets[leader] ?? Offset.zero,
          soldierDesign: roster[leader],
          cohortPalette: palette,
        ),
      );
    }

    for (int i = 0; i < inventorySize; i++) {
      if (!selected[i] || i == leader) continue;
      soldiers.add(
        PlacedSoldier(
          inventoryIndex: i,
          type: SoldierType.triangle,
          localOffset: offsets[i] ?? Offset.zero,
          soldierDesign: roster[i],
          cohortPalette: palette,
        ),
      );
    }

    return CohortDeployment(soldiers: soldiers);
  }
}

class KingdomScoreHistoryPoint {
  const KingdomScoreHistoryPoint({
    required this.periodId,
    required this.granularity,
    required this.territorySizeByFaction,
    required this.landPowerByFaction,
    required this.tributeRevenueByFaction,
  });

  final String periodId;
  final String granularity;
  final Map<SoldierDesignPalette, int> territorySizeByFaction;
  final Map<SoldierDesignPalette, int> landPowerByFaction;
  final Map<SoldierDesignPalette, int> tributeRevenueByFaction;
}
