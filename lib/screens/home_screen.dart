import 'package:flutter/material.dart';
import '../controllers/counter_controller.dart';
import '../widgets/add_edit_counter_sheet.dart';
import '../widgets/counter_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/search_sort_bar.dart';

/// Main screen displaying the list of counters, search/sort filters, and creation actions.
class HomeScreen extends StatelessWidget {
  final CounterController controller;

  const HomeScreen({
    super.key,
    required this.controller,
  });

  void _openAddSheet(BuildContext context) {
    AddEditCounterSheet.show(
      context,
      onSave: ({
        required String title,
        required int initialCount,
        required int step,
        required int colorHex,
        int? target,
        required bool allowNegative,
      }) {
        controller.addCounter(
          title: title,
          initialCount: initialCount,
          step: step,
          colorHex: colorHex,
          target: target,
          allowNegative: allowNegative,
        );
      },
    );
  }

  void _openEditSheet(BuildContext context, String counterId) {
    final counter = controller.filteredCounters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => controller.filteredCounters.first,
    );

    AddEditCounterSheet.show(
      context,
      counterToEdit: counter,
      onSave: ({
        required String title,
        required int initialCount,
        required int step,
        required int colorHex,
        int? target,
        required bool allowNegative,
      }) {
        controller.updateCounter(
          id: counter.id,
          title: title,
          count: initialCount,
          step: step,
          colorHex: colorHex,
          target: target,
          clearTarget: target == null,
          allowNegative: allowNegative,
        );
      },
    );
  }

  void _handleDelete(BuildContext context, String id) {
    final (deletedCounter, index) = controller.deleteCounter(id);
    if (deletedCounter == null) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${deletedCounter.title}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: () {
            controller.restoreCounter(deletedCounter, index);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final counters = controller.filteredCounters;
        final hasCounters = counters.isNotEmpty;
        final totalCounters = controller.totalCountersCount;
        final totalCountSum = controller.totalCountSum;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Counters'),
            actions: [
              if (totalCounters > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$totalCounters items • Total: $totalCountSum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Column(
                    children: [
                      // Search and Sort Bar (shown when there are counters or during active search)
                      if (totalCounters > 0 || controller.searchQuery.isNotEmpty)
                        SearchSortBar(
                          searchQuery: controller.searchQuery,
                          sortOption: controller.sortOption,
                          onSearchChanged: controller.setSearchQuery,
                          onSortChanged: controller.setSortOption,
                        ),

                      // Counters List or Empty State
                      Expanded(
                        child: !hasCounters
                            ? EmptyState(
                                isSearching: controller.searchQuery.isNotEmpty,
                                onAddCounter: () => _openAddSheet(context),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 96, top: 4),
                                itemCount: counters.length,
                                itemBuilder: (context, index) {
                                  final counter = counters[index];
                                  return Dismissible(
                                    key: Key('counter_${counter.id}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      alignment: Alignment.centerRight,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: theme.colorScheme.onErrorContainer,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.delete_outline,
                                            color: theme.colorScheme.onErrorContainer,
                                            size: 26,
                                          ),
                                        ],
                                      ),
                                    ),
                                    onDismissed: (_) => _handleDelete(context, counter.id),
                                    child: CounterCard(
                                      counter: counter,
                                      onIncrement: () => controller.increment(counter.id),
                                      onDecrement: () => controller.decrement(counter.id),
                                      onReset: () => controller.reset(counter.id),
                                      onEdit: () => _openEditSheet(context, counter.id),
                                      onDelete: () => _handleDelete(context, counter.id),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddSheet(context),
            icon: const Icon(Icons.add),
            label: const Text(
              'New Counter',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}
