import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:study_library/features/search/data/repositories/search_repository.dart';
import 'package:study_library/features/search/presentation/providers/search_provider.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _query = '';
  List<SearchResultItem> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _query = query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
      return;
    }

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await ref.read(searchRepositoryProvider).searchAll(libraryId, cleanQuery);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onTap(SearchResultItem result) {
    if (result.route != null) {
      context.push(result.route!);
    } else {
      switch (result.type) {
        case SearchResultType.student:
          context.push('/admin/students/${result.id}');
          break;
        case SearchResultType.plan:
          context.push('/admin/plans');
          break;
        case SearchResultType.announcement:
          context.push('/admin/announcements');
          break;
        case SearchResultType.payment:
          context.push('/admin/payments');
          break;
        case SearchResultType.seat:
          context.push('/admin/seats');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'Search by student, desk #, phone, receipt...',
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onQueryChanged('');
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _query.trim().length < 2
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded, size: 64, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Type at least 2 characters to search',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.search_off_rounded,
                      title: 'No results found',
                      message: 'No records matched "$_query". Try searching with a phone number, name, or desk number.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _results.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: result.color.withValues(alpha: 0.15),
                            child: Icon(result.icon, color: result.color, size: 20),
                          ),
                          title: Text(result.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(result.subtitle),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                          onTap: () => _onTap(result),
                        );
                      },
                    ),
    );
  }
}
