import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/counter_controller.dart';
import '../data/models/counter_log_entry.dart';

/// Dedicated screen displaying the chronological history of counter interactions.
class HistoryScreen extends StatelessWidget {
  final CounterController controller;

  const HistoryScreen({
    super.key,
    required this.controller,
  });

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Activity History?'),
        content: const Text(
          'This will permanently delete all recorded tap history and timestamps. Your counters and current counts will not be affected.',
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
              controller.clearAllLogs();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm:ss a');
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final logs = controller.filteredLogs;
        final allCounters = controller.filteredCounters;
        final selectedId = controller.selectedLogCounterId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Activity History'),
            actions: [
              if (controller.logs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear History',
                  onPressed: () => _showClearConfirmation(context),
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filter Chips Bar (All vs specific counter)
              if (allCounters.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All Activity'),
                          selected: selectedId == null,
                          onSelected: (_) => controller.filterLogsByCounter(null),
                        ),
                        const SizedBox(width: 8),
                        ...allCounters.map((c) {
                          final isSelected = selectedId == c.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(c.colorHex),
                              ),
                              label: Text(c.title),
                              selected: isSelected,
                              onSelected: (_) {
                                controller.filterLogsByCounter(
                                  isSelected ? null : c.id,
                                );
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              // Activity Feed List or Empty State
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off_rounded,
                                size: 72,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selectedId != null
                                    ? 'No activity for this counter'
                                    : 'No activity recorded yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedId != null
                                    ? 'Taps on this counter will appear here.'
                                    : 'Tap (+) or (-) on any counter to start tracking press events.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final showDateHeader = index == 0 ||
                              !_isSameDay(log.timestamp, logs[index - 1].timestamp);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDateHeader) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
                                  child: Text(
                                    _formatDateHeader(log.timestamp, dateFormat),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.primary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                              _buildLogCard(context, log, timeFormat),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date, DateFormat fallback) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final logDay = DateTime(date.year, date.month, date.day);

    if (logDay == today) return 'Today';
    if (logDay == yesterday) return 'Yesterday';
    return fallback.format(date);
  }

  Widget _buildLogCard(BuildContext context, CounterLogEntry log, DateFormat timeFormat) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final counterColor = Color(log.counterColorHex);

    final (actionColor, actionIcon, actionLabel) = switch (log.actionType) {
      CounterActionType.increment => (
          const Color(0xFF16A34A),
          Icons.add_rounded,
          '+${log.changeAmount}',
        ),
      CounterActionType.decrement => (
          const Color(0xFFEA580C),
          Icons.remove_rounded,
          '${log.changeAmount}',
        ),
      CounterActionType.reset => (
          theme.colorScheme.error,
          Icons.restart_alt_rounded,
          'Reset',
        ),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Color dot & Action indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                actionIcon,
                color: actionColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Details: Title and timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: counterColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          log.counterTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeFormat.format(log.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Action Badge & Resulting Count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      color: actionColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Count: ${log.resultingCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
