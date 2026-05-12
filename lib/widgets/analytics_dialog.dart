import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AnalyticsDialog extends StatefulWidget {
  const AnalyticsDialog({super.key});

  @override
  State<AnalyticsDialog> createState() => _AnalyticsDialogState();
}

class _AnalyticsDialogState extends State<AnalyticsDialog> {
  bool _isLoading = true;
  String _error = '';

  List<FlSpot> _redTerritory = [];
  List<FlSpot> _yellowTerritory = [];
  List<FlSpot> _blueTerritory = [];

  List<FlSpot> _redPower = [];
  List<FlSpot> _yellowPower = [];
  List<FlSpot> _bluePower = [];

  List<FlSpot> _redRevenue = [];
  List<FlSpot> _yellowRevenue = [];
  List<FlSpot> _blueRevenue = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('scores')
          .doc('kingdom_daily_score')
          .get();

      if (!doc.exists) {
        _loadMockData();
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final days = data['days'] as Map<String, dynamic>;

      // Sort by date key
      final sortedKeys = days.keys.toList()..sort();

      final List<FlSpot> redT = [];
      final List<FlSpot> yellowT = [];
      final List<FlSpot> blueT = [];

      final List<FlSpot> redP = [];
      final List<FlSpot> yellowP = [];
      final List<FlSpot> blueP = [];

      final List<FlSpot> redR = [];
      final List<FlSpot> yellowR = [];
      final List<FlSpot> blueR = [];

      int i = 0;
      for (final key in sortedKeys) {
        final dayData = days[key] as Map<String, dynamic>;
        
        final red = dayData['red'] as Map<String, dynamic>;
        final yellow = dayData['yellow'] as Map<String, dynamic>;
        final blue = dayData['blue'] as Map<String, dynamic>;

        final double x = i.toDouble();

        redT.add(FlSpot(x, (red['territory_size'] as num).toDouble()));
        yellowT.add(FlSpot(x, (yellow['territory_size'] as num).toDouble()));
        blueT.add(FlSpot(x, (blue['territory_size'] as num).toDouble()));

        redP.add(FlSpot(x, (red['land_power'] as num).toDouble()));
        yellowP.add(FlSpot(x, (yellow['land_power'] as num).toDouble()));
        blueP.add(FlSpot(x, (blue['land_power'] as num).toDouble()));

        redR.add(FlSpot(x, (red['tribute_revenue'] as num).toDouble()));
        yellowR.add(FlSpot(x, (yellow['tribute_revenue'] as num).toDouble()));
        blueR.add(FlSpot(x, (blue['tribute_revenue'] as num).toDouble()));

        i++;
      }

      setState(() {
        _redTerritory = redT;
        _yellowTerritory = yellowT;
        _blueTerritory = blueT;

        _redPower = redP;
        _yellowPower = yellowP;
        _bluePower = blueP;

        _redRevenue = redR;
        _yellowRevenue = yellowR;
        _blueRevenue = blueR;

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadMockData() {
    final List<FlSpot> redT = [];
    final List<FlSpot> yellowT = [];
    final List<FlSpot> blueT = [];

    final List<FlSpot> redP = [];
    final List<FlSpot> yellowP = [];
    final List<FlSpot> blueP = [];

    final List<FlSpot> redR = [];
    final List<FlSpot> yellowR = [];
    final List<FlSpot> blueR = [];

    for (int i = 0; i < 30; i++) {
      final double x = i.toDouble();
      redT.add(FlSpot(x, 600 + (i % 5) * 10));
      yellowT.add(FlSpot(x, 600 - (i % 5) * 10));
      blueT.add(FlSpot(x, 600 + (i % 3) * 5));

      redP.add(FlSpot(x, 600 + (i % 4) * 15));
      yellowP.add(FlSpot(x, 600 - (i % 4) * 15));
      blueP.add(FlSpot(x, 600 + (i % 2) * 20));

      redR.add(FlSpot(x, 70000 + (i % 6) * 5000));
      yellowR.add(FlSpot(x, 70000 - (i % 6) * 5000));
      blueR.add(FlSpot(x, 70000 + (i % 3) * 8000));
    }

    setState(() {
      _redTerritory = redT;
      _yellowTerritory = yellowT;
      _blueTerritory = blueT;

      _redPower = redP;
      _yellowPower = yellowP;
      _bluePower = blueP;

      _redRevenue = redR;
      _yellowRevenue = yellowR;
      _blueRevenue = blueR;

      _isLoading = false;
    });
  }

  Widget _buildLineChart(
    String title,
    List<FlSpot> redSpots,
    List<FlSpot> yellowSpots,
    List<FlSpot> blueSpots,
  ) {
    if (redSpots.isEmpty) return const SizedBox();

    // Determine Y range
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (final spots in [redSpots, yellowSpots, blueSpots]) {
      for (final spot in spots) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }

    final double range = maxY - minY;
    final double padding = range * 0.1;
    minY = minY - padding;
    maxY = maxY + padding;
    if (minY < 0) minY = 0;

    final lineBarsData = [
      LineChartBarData(
        spots: redSpots,
        isCurved: true,
        color: Colors.redAccent,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: yellowSpots,
        isCurved: true,
        color: Colors.amber,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: blueSpots,
        isCurved: true,
        color: Colors.blueAccent,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      ),
    ];

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    show: true,
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: _leftTitleWidgets,
                      ),
                    ),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          const FlLine(color: Colors.white, strokeWidth: 1, dashArray: [4, 4]),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: barData.color ?? Colors.white,
                              strokeWidth: 2,
                              strokeColor: Colors.black,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.black87,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final textStyle = TextStyle(
                            color: touchedSpot.bar.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          );
                          return LineTooltipItem(
                            touchedSpot.y.round().toString(),
                            textStyle,
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: lineBarsData,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _leftTitleWidgets(double value, TitleMeta meta) {
    if (value == meta.max || value == meta.min) {
      return Container();
    }
    
    String text;
    if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(1)}k';
    } else {
      text = value.toInt().toString();
    }

    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFF161F2E),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kingdom Daily Analytics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularPointProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            children: [
                              _buildLineChart(
                                'Territory Size',
                                _redTerritory,
                                _yellowTerritory,
                                _blueTerritory,
                              ),
                              _buildLineChart(
                                'Land Power',
                                _redPower,
                                _yellowPower,
                                _bluePower,
                              ),
                              _buildLineChart(
                                'Tribute Revenue',
                                _redRevenue,
                                _yellowRevenue,
                                _blueRevenue,
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircularPointProgressIndicator extends StatelessWidget {
  const CircularPointProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        color: Colors.cyan,
      ),
    );
  }
}
