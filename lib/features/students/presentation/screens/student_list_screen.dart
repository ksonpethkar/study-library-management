import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:printing/printing.dart';
import '../providers/student_providers.dart';
import '../../../../core/providers/library_provider.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/id_card_template_model.dart';
import 'package:study_library/services/id_card_pdf_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/features/settings/presentation/screens/id_card_customizer_screen.dart';
import 'package:study_library/core/widgets/loading_skeleton.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<StudentModel>? _searchResults;
  bool _isSearching = false;
  Timer? _debounce;
  String _selectedFilter = 'All';
  Set<String> _selectedStudentIds = {};
  bool _isSelectionMode = false;
  late final ScrollController _scrollController;
  
  final List<String> _filters = ['All', 'Active', 'Expired', 'Grace', 'Pending', 'Archived'];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(studentPageProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<StudentModel> _filteredStudents(List<StudentModel> all) {
    if (_searchQuery.isEmpty) return all;
    return all.where((s) {
      final q = _searchQuery;
      return s.name.toLowerCase().contains(q) ||
          s.phone.contains(q) ||
          (s.membershipNumber?.toLowerCase().contains(q) ?? false) ||
          s.email.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _runSearch(String query) async {
    if (query.isEmpty) {
      setState(() { _searchResults = null; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .get();
      final results = snap.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})).toList();
      
      final snap2 = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .where('membershipNumber', isGreaterThanOrEqualTo: query.toUpperCase())
          .where('membershipNumber', isLessThanOrEqualTo: '${query.toUpperCase()}\uf8ff')
          .limit(5)
          .get();
      final results2 = snap2.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})).toList();
      
      final snap3 = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .where('phone', isGreaterThanOrEqualTo: query)
          .where('phone', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .get();
      final results3 = snap3.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})).toList();
      
      final seen = <String>{};
      final merged = [...results, ...results2, ...results3].where((s) => seen.add(s.id)).toList();
      if (mounted) {
        setState(() { _searchResults = merged; _isSearching = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentState = ref.watch(studentPageProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedStudentIds.length} Selected') 
            : const Text('Students'),
        actions: [
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => ref.read(studentPageProvider.notifier).refresh(),
            ),
            IconButton(
              icon: const Icon(Icons.badge_rounded),
              tooltip: 'Print All ID Cards (A4 Sheets)',
              onPressed: () {
                final all = studentState.students;
                if (all.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No students found to print.')),
                  );
                  return;
                }
                _printBulkIdCards(all);
              },
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import CSV',
              onPressed: () => context.push('/admin/students/import'),
            ),
          ],
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.badge_rounded),
              tooltip: 'Print Selected ID Cards',
              onPressed: () {
                final all = studentState.students;
                final selected = all.where((s) => _selectedStudentIds.contains(s.id)).toList();
                if (selected.isEmpty) return;
                _printBulkIdCards(selected);
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_off_outlined),
              tooltip: 'Deactivate selected',
              onPressed: _bulkDeactivate,
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export selected as CSV',
              onPressed: _bulkExportCsv,
            ),
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Send announcement',
              onPressed: _bulkAnnounce,
            ),
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              tooltip: 'Select All',
              onPressed: () {
                final allStudents = studentState.students;
                setState(() {
                  _selectedStudentIds = allStudents.map((s) => s.id).toSet();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Selected',
              onPressed: _bulkDelete,
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Cancel',
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedStudentIds.clear();
              }),
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or ID...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _searchResults = null;
                            });
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (v) {
                  setState(() => _searchQuery = v.toLowerCase().trim());
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(v.trim()));
                },
              ),
            ),
          if (!_isSelectionMode)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: _filters.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _selectedFilter == f,
                    onSelected: (s) {
                      if (s) setState(() => _selectedFilter = f);
                    },
                  ),
                )).toList(),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (studentState.isLoading && studentState.students.isEmpty && !_isSearching) {
                  return const StudentListSkeleton(count: 6);
                }
                if (studentState.error != null && studentState.students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${studentState.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(studentPageProvider.notifier).refresh(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                // Apply search and filter
                final students = studentState.students;
                final searchResults = _searchResults ?? _filteredStudents(students);
                var filtered = searchResults.where((s) {
                  final matchesFilter = _selectedFilter == 'All' || 
                                        s.membershipStatus.name.toLowerCase() == _selectedFilter.toLowerCase();
                  return matchesFilter;
                }).toList();

                if (students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No students yet', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Add your first student to get started', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _navigateToAddStudent(context),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Student'),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No matching students', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Try changing your search or filter', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(studentPageProvider.notifier).loadFirst();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        if (studentState.isLoading && studentState.students.isNotEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          );
                        }
                        if (!studentState.hasMore) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                'No more students',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      final student = filtered[index];
                      final isSelected = _selectedStudentIds.contains(student.id);

                      return PressableScale(
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              isSelected ? _selectedStudentIds.remove(student.id) : _selectedStudentIds.add(student.id);
                              if (_selectedStudentIds.isEmpty) _isSelectionMode = false;
                            });
                          } else {
                            context.go('/admin/students/${student.id}');
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedStudentIds.add(student.id);
                          });
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: ImageService.getImageProvider(student.photoUrl),
                              child: ImageService.getImageProvider(student.photoUrl) == null
                                  ? Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?')
                                  : null,
                            ),
                            title: Text(student.name),
                            subtitle: Text('${student.membershipNumber != null ? "#${student.membershipNumber} \u2022 " : ''}${student.phone} \u2022 ${student.membershipStatus.name}'),
                            trailing: _isSelectionMode
                                ? Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
                                    color: isSelected ? theme.colorScheme.primary : null)
                                : Chip(
                                    label: Text(student.membershipStatus.name,
                                      style: const TextStyle(fontSize: 11)),
                                  ),
                            selected: isSelected,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !_isSelectionMode ? FloatingActionButton(
        onPressed: () => _navigateToAddStudent(context),
        child: const Icon(Icons.person_add),
      ) : null,
    );
  }

  void _navigateToAddStudent(BuildContext context) {
    context.go('/admin/students/add');
  }

  Future<void> _bulkDelete() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || _selectedStudentIds.isEmpty) return;

    final count = _selectedStudentIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count Students?'),
        content: Text('Are you sure you want to delete $count selected students? This will remove them from the active list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repo = ref.read(studentRepositoryProvider);
        await repo.bulkDelete(libraryId, _selectedStudentIds.toList());
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
        ref.read(studentPageProvider.notifier).refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully deleted $count students.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete students: $e')),
          );
        }
      }
    }
  }

  Future<void> _bulkDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate Students'),
        content: Text('Deactivate ${_selectedStudentIds.length} selected student(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    final repo = ref.read(studentRepositoryProvider);
    int success = 0;
    for (final id in _selectedStudentIds) {
      try {
        await repo.deactivateStudent(libraryId, id);
        success++;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _isSelectionMode = false; _selectedStudentIds.clear(); });
    ref.read(studentPageProvider.notifier).refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$success student(s) deactivated'), backgroundColor: Colors.orange),
    );
  }

  Future<void> _bulkExportCsv() async {
    final pageState = ref.read(studentPageProvider);
    final selected = pageState.students.where((s) => _selectedStudentIds.contains(s.id)).toList();
    
    final buf = StringBuffer();
    buf.writeln('Name,Phone,Email,Membership ID,Plan,Status,Seat,Joined');
    for (final s in selected) {
      buf.writeln('"${s.name}","${s.phone}","${s.email}","${s.membershipNumber ?? ''}","${s.planId ?? ''}","${s.membershipStatus.name}","${s.seatId ?? ''}","${s.createdAt?.toIso8601String() ?? ''}"');
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/students_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Students Export'));
      if (mounted) setState(() { _isSelectionMode = false; _selectedStudentIds.clear(); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _bulkAnnounce() async {
    String? message;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('Announce to ${_selectedStudentIds.length} students'),
          content: TextFormField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter your message...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                message = ctrl.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Send via WhatsApp'),
            ),
          ],
        );
      },
    );
    
    if (message == null || message!.isEmpty) return;
    
    final pageState = ref.read(studentPageProvider);
    final selected = pageState.students.where((s) => _selectedStudentIds.contains(s.id)).toList();
    
    if (!mounted) return;
    final phones = selected.where((s) => s.phone.isNotEmpty).map((s) => s.phone).toList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message prepared for ${phones.length} students. Opening WhatsApp...'),
        duration: const Duration(seconds: 3),
      ),
    );
    
    if (phones.isNotEmpty) {
      final encoded = Uri.encodeComponent(message!);
      final url = Uri.parse('https://wa.me/${phones.first.replaceAll(RegExp(r'[^0-9]'), '')}?text=$encoded');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    
    setState(() { _isSelectionMode = false; _selectedStudentIds.clear(); });
  }

  Future<void> _printBulkIdCards(List<StudentModel> students) async {
    if (students.isEmpty) return;
    final libraryAsync = ref.read(currentLibraryProvider);
    final library = libraryAsync.value;
    if (library == null) return;

    final templateAsync = ref.read(idCardTemplateProvider);
    final settings = templateAsync.value ?? const IdCardTemplateSettings();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating Batch ID Cards (A4 Sheets)...', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Packing 4 cards per sheet to save paper', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final pdfBytes = await IdCardPdfService.generateBulkIdCards(
        students: students,
        library: library,
        settings: settings,
      );

      if (mounted) Navigator.pop(context); // close loader

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Batch_Student_ID_Cards.pdf',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating batch ID cards: $e')),
        );
      }
    }
  }
}

/// Quick add student form — inline for now
class _AddStudentQuickForm extends ConsumerStatefulWidget {
  final String libraryId;
  const _AddStudentQuickForm({required this.libraryId});

  @override
  ConsumerState<_AddStudentQuickForm> createState() => _AddStudentQuickFormState();
}

class _AddStudentQuickFormState extends ConsumerState<_AddStudentQuickForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  String _gender = 'male';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.addStudent(
        libraryId: widget.libraryId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        gender: _gender,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Valid phone required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address (Optional)',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.people),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'male'),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _saveStudent,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Student'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

