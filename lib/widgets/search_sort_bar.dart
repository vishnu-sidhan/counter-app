import 'package:flutter/material.dart';
import '../controllers/counter_controller.dart';

/// Quick search bar with integrated sort menu for filtering and ordering counters.
class SearchSortBar extends StatefulWidget {
  final String searchQuery;
  final SortOption sortOption;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SortOption> onSortChanged;

  const SearchSortBar({
    super.key,
    required this.searchQuery,
    required this.sortOption,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  @override
  State<SearchSortBar> createState() => _SearchSortBarState();
}

class _SearchSortBarState extends State<SearchSortBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant SearchSortBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Search input field
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search counters...',
                prefixIcon: const Icon(Icons.search, size: 22),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          widget.onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sort Menu Button
          PopupMenuButton<SortOption>(
            initialValue: widget.sortOption,
            tooltip: 'Sort by',
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.sort_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: widget.onSortChanged,
            itemBuilder: (ctx) => SortOption.values.map((option) {
              final isSelected = widget.sortOption == option;
              return PopupMenuItem<SortOption>(
                value: option,
                child: Row(
                  children: [
                    Icon(
                      switch (option) {
                        SortOption.recentlyUpdated => Icons.access_time_rounded,
                        SortOption.highestCount => Icons.trending_up_rounded,
                        SortOption.alphabetical => Icons.sort_by_alpha_rounded,
                        SortOption.custom => Icons.drag_handle_rounded,
                      },
                      size: 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
