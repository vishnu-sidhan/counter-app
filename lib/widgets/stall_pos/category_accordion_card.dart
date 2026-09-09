import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/stall_models.dart';

/// Collapsible accordion card representing a menu category in the POS register.
class CategoryAccordionCard extends StatelessWidget {
  final String catName;
  final List<MenuItem> items;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Color Function(String category) getCategoryColor;
  final Widget Function(MenuItem item) itemCardBuilder;

  const CategoryAccordionCard({
    super.key,
    required this.catName,
    required this.items,
    required this.isExpanded,
    required this.onToggle,
    required this.getCategoryColor,
    required this.itemCardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = getCategoryColor(catName);

    return Card(
      key: PageStorageKey('pos_category_$catName'),
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: catColor.withAlpha(60),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 24,
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      catName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: catColor.withAlpha(90)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${items.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          items.length == 1 ? 'item' : 'items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: catColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth.isFinite &&
                          constraints.maxWidth > 0
                      ? constraints.maxWidth
                      : (MediaQuery.of(context).size.width - 24);
                  const double maxExtent = 165.0;
                  const double spacing = 12.0;
                  const double childAspectRatio = 0.98;
                  int crossAxisCount =
                      (availableWidth / (maxExtent + spacing)).ceil();
                  crossAxisCount = crossAxisCount < 1 ? 1 : crossAxisCount;
                  final double usableWidth = math.max(
                    0.0,
                    availableWidth - spacing * (crossAxisCount - 1),
                  );
                  final double childWidth = usableWidth / crossAxisCount;
                  final double childHeight = childWidth / childAspectRatio;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: items.map((menuItem) {
                      return SizedBox(
                        width: childWidth,
                        height: childHeight,
                        child: itemCardBuilder(menuItem),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}
