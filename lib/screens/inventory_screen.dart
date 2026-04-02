import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cohort_models.dart';
import '../widgets/soldier_inventory_tile.dart';
import '../widgets/triangle_soldier.dart';
import 'war_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const int _inventorySize = 11;

  /// Drag within this distance of the crosshair snaps to exact center (0, 0).
  static const double _centerSnapPx = 14;

  final List<bool> _selected = List<bool>.filled(_inventorySize, true);
  final Map<int, Offset> _offsets = <int, Offset>{};

  @override
  void initState() {
    super.initState();
    const double r = 78;
    for (int i = 0; i < _inventorySize; i++) {
      if (i == 0) {
        _offsets[i] = Offset.zero;
      } else {
        final double a = -math.pi / 2 + i * 0.65;
        _offsets[i] = Offset(math.cos(a) * r, math.sin(a) * r);
      }
    }
  }

  int _ordinalForSlot(int slot) {
    int n = 0;
    for (int i = 0; i <= slot; i++) {
      if (_selected[i]) n++;
    }
    return n - 1;
  }

  void _toggleSlot(int index) {
    setState(() {
      if (_selected[index]) {
        _selected[index] = false;
        _offsets.remove(index);
      } else {
        _selected[index] = true;
        final int ord = _ordinalForSlot(index);
        // First soldier in the cohort starts on the crosshair (matches war: local offset 0,0).
        // Additional soldiers use the ring so they do not stack on the same pixel.
        if (ord == 0) {
          _offsets[index] = Offset.zero;
        } else {
          const double r = 78;
          final double a = -math.pi / 2 + ord * 0.65;
          _offsets[index] = Offset(math.cos(a) * r, math.sin(a) * r);
        }
      }
    });
  }

  void _onDragSoldier(int index, Offset delta, Size panelSize) {
    final Offset half = Offset(panelSize.width / 2, panelSize.height / 2);
    const double margin = 36;
    final double maxX = half.dx - margin;
    final double maxY = half.dy - margin;
    setState(() {
      final Offset o = (_offsets[index] ?? Offset.zero) + delta;
      Offset next = Offset(
        o.dx.clamp(-maxX, maxX),
        o.dy.clamp(-maxY, maxY),
      );
      if (next.distance <= _centerSnapPx) {
        next = Offset.zero;
      }
      _offsets[index] = next;
    });
  }

  CohortDeployment _buildDeployment() {
    final List<PlacedSoldier> list = <PlacedSoldier>[];
    for (int i = 0; i < _inventorySize; i++) {
      if (_selected[i]) {
        list.add(
          PlacedSoldier(
            inventoryIndex: i,
            type: SoldierType.triangle,
            localOffset: _offsets[i] ?? Offset.zero,
          ),
        );
      }
    }
    return CohortDeployment(soldiers: list);
  }

  void _goToWar() {
    final CohortDeployment d = _buildDeployment();
    if (d.soldiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one Triangle soldier.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => WarScreen(deployment: d.copy()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0D0B1A),
              Color(0xFF1A1340),
              Color(0xFF0A1628),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 42,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Soldier inventory',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add or remove from the cohort. All selected by default.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _inventorySize,
                          separatorBuilder: (BuildContext _, int index) {
                            assert(index >= 0);
                            return const SizedBox(height: 10);
                          },
                          itemBuilder: (BuildContext context, int i) {
                            return SoldierInventoryTile(
                              index: i,
                              selected: _selected[i],
                              onTap: () => _toggleSlot(i),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _goToWar,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Go to War',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 58,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints c) {
                          final Size panelSize = Size(c.maxWidth, c.maxHeight);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Positioned(
                                left: 16,
                                top: 12,
                                child: Text(
                                  'Cohort formation',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                top: 40,
                                right: 16,
                                child: Text(
                                  'Drag soldiers relative to the cohort center (crosshair).',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white60,
                                      ),
                                ),
                              ),
                              Center(
                                child: CustomPaint(
                                  size: panelSize,
                                  painter: _CrosshairPainter(),
                                ),
                              ),
                              ..._buildDraggableSoldiers(panelSize),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDraggableSoldiers(Size panelSize) {
    final List<Widget> out = <Widget>[];
    final Offset origin = Offset(panelSize.width / 2, panelSize.height / 2);
    for (int i = 0; i < _inventorySize; i++) {
      if (!_selected[i]) continue;
      final Offset o = _offsets[i] ?? Offset.zero;
      out.add(
        Positioned(
          left: origin.dx + o.dx - 28,
          top: origin.dy + o.dy - 28,
          child: GestureDetector(
            onPanUpdate: (DragUpdateDetails d) => _onDragSoldier(i, d.delta, panelSize),
            child: const TriangleSoldier(size: 56, side: 40, angle: 0),
          ),
        ),
      );
    }
    return out;
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final Paint p = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(c.dx - 14, c.dy), Offset(c.dx + 14, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - 14), Offset(c.dx, c.dy + 14), p);
    canvas.drawCircle(c, 5, Paint()..color = Colors.white24);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
