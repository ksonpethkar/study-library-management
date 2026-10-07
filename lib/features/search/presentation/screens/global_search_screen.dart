import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/providers/library_provider.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  List<_SearchResult> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSearching = true);

    final results = <_SearchResult>[];
    final q = query.trim().toLowerCase();

    try {
      // Search students
      final students = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .get();

      for (final doc in students.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();

        if (name.contains(q) || phone.contains(q) || email.contains(q)) {
          results.add(_SearchResult(
            type: _ResultType.student,
            id: doc.id,
            title: data['name'] ?? '',
            subtitle: data['phone'] ?? '',
            icon: Icons.person,
            color: Colors.blue,
          ));
        }
      }

      // Search plans
      final plans = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('plans')
          .get();

      for (final doc in plans.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();

        if (name.contains(q)) {
          results.add(_SearchResult(
            type: _ResultType.plan,
            id: doc.id,
            title: data['name'] ?? '',
            subtitle: '₹${data['price'] ?? 0} • ${data['durationDays'] ?? 0} days',
            icon: Icons.assignment,
            color: Colors.green,
          ));
        }
      }

      // Search sections
      final sections = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('sections')
          .get();

      for (final doc in sections.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();

        if (name.contains(q)) {
          results.add(_SearchResult(
            type: _ResultType.section,
            id: doc.id,
            title: data['name'] ?? '',
            subtitle: '${data['rows'] ?? 0}×${data['cols'] ?? 0} seats',
            icon: Icons.event_seat,
            color: Colors.orange,
          ));
        }
      }

      // Search announcements
      final announcements = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('announcements')
          .get();

      for (final doc in announcements.docs) {
        final data = doc.data();
        final title = (data['title'] ?? '').toString().toLowerCase();
        final message = (data['message'] ?? '').toString().toLowerCase();

        if (title.contains(q) || message.contains(q)) {
          results.add(_SearchResult(
            type: _ResultType.announcement,
            id: doc.id,
            title: data['title'] ?? '',
            subtitle: data['message'] ?? '',
            icon: Icons.campaign,
            color: Colors.purple,
          ));
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  void _onTap(_SearchResult result) {
    switch (result.type) {
      case _ResultType.student:
        context.push('/admin/students/${result.id}');
        break;
      case _ResultType.plan:
        context.push('/admin/plans');
        break;
      case _ResultType.section:
        // Go to seats
        break;
      case _ResultType.announcement:
        context.push('/admin/announcements');
        break;
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
            hintText: 'Search students, plans, sections...',
            border: InputBorder.none,
          ),
          onChanged: (val) {
            _query = val;
            _search(val);
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _query.trim().length < 2
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('Type at least 2 characters to search',
                          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No results for "$_query"', style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('${_results.length} result${_results.length == 1 ? '' : 's'}',
                                style: theme.textTheme.bodySmall),
                          );
                        }
                        final result = _results[index - 1];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: result.color.withValues(alpha: 0.15),
                            child: Icon(result.icon, color: result.color, size: 20),
                          ),
                          title: Text(result.title),
                          subtitle: Text(result.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Chip(
                            label: Text(result.type.label, style: const TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () => _onTap(result),
                        );
                      },
                    ),
    );
  }
}

enum _ResultType {
  student,
  plan,
  section,
  announcement;

  String get label {
    switch (this) {
      case student: return 'Student';
      case plan: return 'Plan';
      case section: return 'Section';
      case announcement: return 'Announce';
    }
  }
}

class _SearchResult {
  final _ResultType type;
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
