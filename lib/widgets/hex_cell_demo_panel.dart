import 'dart:async';

import 'package:flutter/material.dart';

import '../models/core_color_theme.dart';
import '../models/hex_cell_preview_style.dart';
import 'hex_cell_preview_layout.dart';
import 'hex_cell_styles_paint.dart';

/// Temporary single-cell preview. **Red / Yellow / Blue** is local to this panel.
class HexCellDemoPanel extends StatefulWidget {
  const HexCellDemoPanel({
    super.key,
    required this.style,
    required this.onStyleChanged,
  });

  final HexCellPreviewStyle style;
  final ValueChanged<HexCellPreviewStyle> onStyleChanged;

  @override
  State<HexCellDemoPanel> createState() => _HexCellDemoPanelState();
}

class _HexCellDemoPanelState extends State<HexCellDemoPanel> {
  CoreColorTheme _coreTheme = CoreColorTheme.red;
  Timer? _a2SwapTimer;
  bool _a2SwapThemeRings = false;

  @override
  void initState() {
    super.initState();
    _syncA2SwapTimer();
  }

  @override
  void didUpdateWidget(HexCellDemoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncA2SwapTimer();
  }

  void _syncA2SwapTimer() {
    _a2SwapTimer?.cancel();
    _a2SwapTimer = null;
    if (widget.style == HexCellPreviewStyle.a2 ||
        widget.style == HexCellPreviewStyle.l2) {
      final double periodSec = widget.style == HexCellPreviewStyle.l2
          ? HexCellStylesPaint.l2ThemeCyclePeriodSec
          : HexCellStylesPaint.a2ThemeSwapPeriodSec;
      _a2SwapTimer = Timer.periodic(
        Duration(milliseconds: (periodSec * 1000).round()),
        (_) {
          if (mounted) {
            setState(() {
              _a2SwapThemeRings = !_a2SwapThemeRings;
            });
          }
        },
      );
    } else if (_a2SwapThemeRings) {
      setState(() {
        _a2SwapThemeRings = false;
      });
    }
  }

  @override
  void dispose() {
    _a2SwapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _coreTheme.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _coreTheme.previewPanelBase,
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.55), width: 3),
        ),
      ),
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Core theme',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.95),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  return SizedBox(
                    height: 34,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final CoreColorTheme t in CoreColorTheme.values)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: _themeChip(
                                  label: t.shortLabel,
                                  selected: _coreTheme == t,
                                  accent: t.accent,
                                  onTap: () {
                                    setState(() {
                                      _coreTheme = t;
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Cell preview (temp)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (final HexCellPreviewStyle s
                        in HexCellPreviewStyle.values) ...<Widget>[
                      _styleChip(
                        label: s.label,
                        value: s,
                        selected: widget.style == s,
                        accent: accent,
                        onTap: () => widget.onStyleChanged(s),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      key: ValueKey<int>(
                        Object.hash(
                          widget.style,
                          _coreTheme,
                          _a2SwapThemeRings,
                        ),
                      ),
                      painter: HexCellPreviewPainter(
                        style: widget.style,
                        coreTheme: _coreTheme,
                        a2SwapThemeRings: _a2SwapThemeRings,
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

  Widget _themeChip({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(52, 30),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        backgroundColor: selected
            ? accent.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.06),
        foregroundColor: selected ? Colors.white : accent.withValues(alpha: 0.85),
        side: BorderSide(
          color: selected ? accent : accent.withValues(alpha: 0.35),
          width: selected ? 1.6 : 1,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _styleChip({
    required String label,
    required HexCellPreviewStyle value,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 30),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        backgroundColor: selected
            ? accent.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.08),
        foregroundColor: Colors.white,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}

/// Cell art follows [coreTheme]; **light green** boundary on top (not themed).
class HexCellPreviewPainter extends CustomPainter {
  const HexCellPreviewPainter({
    required this.style,
    required this.coreTheme,
    this.a2SwapThemeRings = false,
  });

  final HexCellPreviewStyle style;
  final CoreColorTheme coreTheme;
  final bool a2SwapThemeRings;

  @override
  void paint(Canvas canvas, Size size) {
    HexCellStylesPaint.paintPreviewContent(
      canvas,
      size,
      style,
      coreTheme: coreTheme,
      a2SwapThemeRings: a2SwapThemeRings,
    );
    final Offset c = HexCellPreviewLayout.center(size);
    final double r = HexCellPreviewLayout.outerRadius(size);
    HexCellPreviewLayout.paintUnifiedHexOutline(
      canvas,
      HexCellPreviewLayout.pathFromVerts(HexCellPreviewLayout.pointyTopVerts(c, r)),
      HexCellPreviewLayout.scale(size),
    );
    HexCellPreviewLayout.paintBoundaryOutline(canvas, size);
  }

  @override
  bool shouldRepaint(covariant HexCellPreviewPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.coreTheme != coreTheme ||
      oldDelegate.a2SwapThemeRings != a2SwapThemeRings;
}
