import 'package:flutter/material.dart';

import 'triangle_soldier.dart';

/// Rounded square tile showing a Triangle soldier preview.
class SoldierInventoryTile extends StatelessWidget {
  const SoldierInventoryTile({
    super.key,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer.withValues(alpha: 0.55) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? cs.primary : Colors.white24,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 72,
                height: 72,
                child: Center(
                  child: TriangleSoldier(size: 56, side: 40, angle: 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Triangle #${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: cs.primary, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
