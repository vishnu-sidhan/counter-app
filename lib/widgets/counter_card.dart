import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/counter_model.dart';

/// Ergonomic, Fitts's-law-optimized card for one-handed counter interaction.
class CounterCard extends StatelessWidget {
  final CounterModel counter;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onReset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onViewHistory;

  const CounterCard({
    super.key,
    required this.counter,
    required this.onIncrement,
    required this.onDecrement,
    required this.onReset,
    required this.onEdit,
    required this.onDelete,
    this.onViewHistory,
  });

  Color get _accentColor => Color(counter.colorHex);

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Counter?'),
        content: Text(
          'Are you sure you want to reset "${counter.title}" back to 0? Current count is ${counter.count}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onReset();
            },
            child: const Text('Reset to 0'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDecrementDisabled = !counter.allowNegative && counter.count <= 0;
    final timeFormat = DateFormat('MMM d, h:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        onLongPress: () => _showResetConfirmation(context),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _accentColor,
                width: 6,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Title, badges, and quick menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          counter.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Step pill badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Step: ±${counter.step}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Updated time
                            Text(
                              timeFormat.format(counter.updatedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Menu actions
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'history':
                          onViewHistory?.call();
                          break;
                        case 'edit':
                          onEdit();
                          break;
                        case 'reset':
                          _showResetConfirmation(context);
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (onViewHistory != null)
                        const PopupMenuItem(
                          value: 'history',
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded, size: 20),
                              SizedBox(width: 12),
                              Text('View History'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Edit Counter'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.restart_alt_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Reset to 0'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Target progress row if target is set
              if (counter.target != null && counter.target! > 0) ...[
                _buildTargetProgress(context),
                const SizedBox(height: 14),
              ],

              // Interaction Row: High-contrast Count Display & Thumb-Friendly Controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // High contrast Count display
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: Text(
                        '${counter.count}',
                        key: ValueKey<int>(counter.count),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: counter.isTargetReached
                              ? _accentColor
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                  ),

                  // Secondary Decrement Button (-)
                  Tooltip(
                    message: 'Decrement (-${counter.step})',
                    child: Material(
                      color: isDecrementDisabled
                          ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: isDecrementDisabled ? null : onDecrement,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Icon(
                              Icons.remove,
                              size: 24,
                              color: isDecrementDisabled
                                  ? theme.disabledColor
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Oversized Tactile Primary Increment Button (+) - Fitts's Law Optimized
                  Tooltip(
                    message: 'Increment (+${counter.step})',
                    child: Material(
                      color: _accentColor,
                      elevation: 3,
                      shadowColor: _accentColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onIncrement,
                        child: Container(
                          width: 72,
                          height: 60,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 28,
                              ),
                              if (counter.step > 1) ...[
                                const SizedBox(width: 2),
                                Text(
                                  '${counter.step}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetProgress(BuildContext context) {
    final theme = Theme.of(context);
    final target = counter.target!;
    final progress = counter.progress ?? 0.0;
    final percentage = counter.progressPercentage ?? 0;
    final isReached = counter.isTargetReached;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isReached ? Icons.check_circle : Icons.flag_outlined,
                    size: 16,
                    color: isReached ? const Color(0xFF16A34A) : _accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isReached ? 'Goal Achieved!' : 'Target: $target',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isReached ? const Color(0xFF16A34A) : _accentColor,
                    ),
                  ),
                ],
              ),
              Text(
                '$percentage%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isReached ? const Color(0xFF16A34A) : _accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: _accentColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isReached ? const Color(0xFF16A34A) : _accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
