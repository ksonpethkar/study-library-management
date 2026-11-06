import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:study_library/core/providers/library_provider.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  // Accordion Expand/Collapse State
  bool _upiExpanded = true;
  bool _bankExpanded = false;
  bool _methodsExpanded = true;
  bool _policiesExpanded = false;
  bool _merchantGuideExpanded = false;

  // UPI Controllers & Limit Tier
  String _accountType = 'p2p'; // 'p2p' (Personal Savings, max 2k deep link) or 'merchant' (P2M, up to 1L+)
  final _upiIdController = TextEditingController();
  final _payeeNameController = TextEditingController();
  final _upiPhoneController = TextEditingController();
  final _mccController = TextEditingController(text: '8299'); // 8299 = Educational / Library / Coaching Services

  // Bank Transfer Controllers
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _branchController = TextEditingController();

  // Cash / Reception Controllers
  final _cashTimingsController = TextEditingController(text: '8:00 AM – 10:00 PM (Daily)');
  final _cashInstructionsController = TextEditingController(text: 'Visit reception desk. Official receipts issued instantly.');

  // Cheque Controllers
  final _chequePayeeController = TextEditingController();

  // Policies Controllers
  final _gracePeriodController = TextEditingController(text: '3');
  final _lateFineController = TextEditingController(text: '0');
  final _gstinController = TextEditingController();
  final _refundPolicyController = TextEditingController(
    text: 'Fees once paid are non-refundable and non-transferable under any circumstances.',
  );

  List<Map<String, dynamic>> _methods = [
    {'id': 'cash', 'name': 'Cash / Pay at Reception', 'active': true, 'details': 'Cash payment at reception desk'},
    {'id': 'upi', 'name': 'UPI / QR Code', 'active': true, 'details': 'GPay / PhonePe / Paytm / BHIM Scan & Pay'},
    {'id': 'card', 'name': 'Debit / Credit Card', 'active': true, 'details': 'POS Card Swipe at reception'},
    {'id': 'bank', 'name': 'Bank Transfer', 'active': false, 'details': 'NEFT / RTGS / IMPS Direct Transfer'},
    {'id': 'cheque', 'name': 'Cheque / DD', 'active': false, 'details': 'Cheque in favour of library'},
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _payeeNameController.dispose();
    _upiPhoneController.dispose();
    _mccController.dispose();

    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _accountHolderController.dispose();
    _branchController.dispose();

    _cashTimingsController.dispose();
    _cashInstructionsController.dispose();
    _chequePayeeController.dispose();

    _gracePeriodController.dispose();
    _lateFineController.dispose();
    _gstinController.dispose();
    _refundPolicyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('payment_methods')
          .get();

      final libDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .get();

      final libData = libDoc.data() ?? {};
      final defaultPayee = libData['name']?.toString() ?? 'Study Library';
      final rawPhone = (libData['contact']?.toString() ?? libData['phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
      final defaultUpi = (libData['upiId']?.toString().isNotEmpty == true)
          ? libData['upiId'].toString()
          : (rawPhone.isNotEmpty ? '$rawPhone@upi' : 'library@upi');

      if (mounted) {
        if (doc.exists) {
          final data = doc.data()!;
          if (data['methods'] is List) {
            _methods = (data['methods'] as List)
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          }
          _upiIdController.text = data['upiId']?.toString().isNotEmpty == true
              ? data['upiId'].toString()
              : defaultUpi;
          _payeeNameController.text = data['payeeName']?.toString().isNotEmpty == true
              ? data['payeeName'].toString()
              : defaultPayee;
          _upiPhoneController.text = data['upiPhone']?.toString() ?? rawPhone;
          _accountType = data['accountType']?.toString() == 'merchant' ? 'merchant' : 'p2p';
          _mccController.text = data['mcc']?.toString().isNotEmpty == true ? data['mcc'].toString() : '8299';

          // Bank Details
          if (data['bankDetails'] is Map) {
            final b = Map<String, dynamic>.from(data['bankDetails'] as Map);
            _bankNameController.text = b['bankName']?.toString() ?? '';
            _accountNumberController.text = b['accountNumber']?.toString() ?? '';
            _ifscCodeController.text = b['ifscCode']?.toString() ?? '';
            _accountHolderController.text = b['accountHolder']?.toString() ?? defaultPayee;
            _branchController.text = b['branch']?.toString() ?? '';
          } else {
            _accountHolderController.text = defaultPayee;
          }

          // Cash Details
          if (data['cashDetails'] is Map) {
            final c = Map<String, dynamic>.from(data['cashDetails'] as Map);
            if (c['timings']?.toString().isNotEmpty == true) {
              _cashTimingsController.text = c['timings'].toString();
            }
            if (c['instructions']?.toString().isNotEmpty == true) {
              _cashInstructionsController.text = c['instructions'].toString();
            }
          }

          // Cheque Details
          if (data['chequeDetails'] is Map) {
            final ch = Map<String, dynamic>.from(data['chequeDetails'] as Map);
            _chequePayeeController.text = ch['payeeName']?.toString() ?? defaultPayee;
          } else {
            _chequePayeeController.text = defaultPayee;
          }

          // Policies
          if (data['policies'] is Map) {
            final p = Map<String, dynamic>.from(data['policies'] as Map);
            _gracePeriodController.text = p['gracePeriodDays']?.toString() ?? '3';
            _lateFineController.text = p['lateFinePerDay']?.toString() ?? '0';
            _gstinController.text = p['gstin']?.toString() ?? '';
            if (p['refundPolicy']?.toString().isNotEmpty == true) {
              _refundPolicyController.text = p['refundPolicy'].toString();
            }
          }
        } else {
          _upiIdController.text = defaultUpi;
          _payeeNameController.text = defaultPayee;
          _upiPhoneController.text = rawPhone;
          _accountHolderController.text = defaultPayee;
          _chequePayeeController.text = defaultPayee;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final upiId = _upiIdController.text.trim();
    final payeeName = _payeeNameController.text.trim();
    final upiPhone = _upiPhoneController.text.trim();

    final upiVpaRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    if (upiId.isNotEmpty && !upiVpaRegex.hasMatch(upiId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid UPI ID (e.g. library@bank or 9876543210@upi)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bankDetails = {
      'bankName': _bankNameController.text.trim(),
      'accountNumber': _accountNumberController.text.trim(),
      'ifscCode': _ifscCodeController.text.trim().toUpperCase(),
      'accountHolder': _accountHolderController.text.trim(),
      'branch': _branchController.text.trim(),
    };

    final cashDetails = {
      'timings': _cashTimingsController.text.trim(),
      'instructions': _cashInstructionsController.text.trim(),
    };

    final chequeDetails = {
      'payeeName': _chequePayeeController.text.trim(),
    };

    final policies = {
      'gracePeriodDays': int.tryParse(_gracePeriodController.text.trim()) ?? 3,
      'lateFinePerDay': double.tryParse(_lateFineController.text.trim()) ?? 0.0,
      'gstin': _gstinController.text.trim(),
      'refundPolicy': _refundPolicyController.text.trim(),
    };

    setState(() => _isSaving = true);
    try {
      // 1. Save payment_methods settings doc
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('payment_methods')
          .set({
        'upiId': upiId,
        'payeeName': payeeName,
        'upiPhone': upiPhone,
        'accountType': _accountType,
        'mcc': _mccController.text.trim().isNotEmpty ? _mccController.text.trim() : '8299',
        'bankDetails': bankDetails,
        'cashDetails': cashDetails,
        'chequeDetails': chequeDetails,
        'policies': policies,
        'methods': _methods,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Sync core payment fields to library doc for fast global access & receipt generation
      final enabledMethods = _methods
          .where((m) => m['active'] == true)
          .map((m) => m['id'].toString().toLowerCase())
          .toList();

      final syncData = <String, dynamic>{
        'upiId': upiId,
        'enabledPaymentMethods': enabledMethods,
      };
      if (bankDetails['bankName']!.isNotEmpty) {
        syncData['bankName'] = bankDetails['bankName'];
      }
      if (policies['gstin'].toString().isNotEmpty) {
        syncData['gstin'] = policies['gstin'];
      }

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .set(syncData, SetOptions(merge: true));

      ref.invalidate(currentLibraryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment methods, bank details & policies saved successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleMethod(int index, bool newValue) async {
    final method = _methods[index];
    final id = method['id']?.toString().toLowerCase() ?? '';

    // GATING RULE: If enabling bank transfer, require valid bank details
    if (newValue == true && id == 'bank') {
      final hasBankDetails = _bankNameController.text.trim().isNotEmpty &&
          _accountNumberController.text.trim().isNotEmpty &&
          _ifscCodeController.text.trim().isNotEmpty;
      if (!hasBankDetails) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() => _bankExpanded = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please configure official Bank Name, Account Number and IFSC Code before enabling Bank Transfer.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    HapticFeedback.selectionClick();
    setState(() {
      _methods[index]['active'] = newValue;
    });

    // Immediate atomic autosave to Firestore (Stripe / Razorpay pattern)
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    try {
      final enabledMethods = _methods
          .where((m) => m['active'] == true)
          .map((m) => m['id'].toString().toLowerCase())
          .toList();

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('payment_methods')
          .set({
        'methods': _methods,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .set({
        'enabledPaymentMethods': enabledMethods,
      }, SetOptions(merge: true));

      ref.invalidate(currentLibraryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${method['name']} ${newValue ? "enabled" : "disabled"} for students & reception.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: newValue ? Colors.green.shade800 : Colors.blueGrey.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _methods[index]['active'] = !newValue;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update payment method: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBankDetailsDialog() {
    final bNameCtrl = TextEditingController(text: _bankNameController.text);
    final accCtrl = TextEditingController(text: _accountNumberController.text);
    final ifscCtrl = TextEditingController(text: _ifscCodeController.text);
    final holderCtrl = TextEditingController(text: _accountHolderController.text);
    final branchCtrl = TextEditingController(text: _branchController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_rounded, color: Color(0xFF00796B)),
            SizedBox(width: 8),
            Text('Bank Account Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank Name *',
                  hintText: 'e.g. HDFC Bank, SBI, ICICI Bank',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: holderCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name *',
                  hintText: 'e.g. Study Library Center',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Account Number *',
                  hintText: 'e.g. 50200012345678',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ifscCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'IFSC Code *',
                  hintText: 'e.g. HDFC0001234',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security_rounded),
                  helperText: '11-character Indian Financial System Code',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: branchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Name (Optional)',
                  hintText: 'e.g. MG Road Branch, Pune',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _bankNameController.text = bNameCtrl.text.trim();
                _accountHolderController.text = holderCtrl.text.trim();
                _accountNumberController.text = accCtrl.text.trim();
                _ifscCodeController.text = ifscCtrl.text.trim().toUpperCase();
                _branchController.text = branchCtrl.text.trim();

                // Ensure 'bank' method is marked active if details are provided
                if (_bankNameController.text.isNotEmpty && _accountNumberController.text.isNotEmpty) {
                  final bankIdx = _methods.indexWhere((m) => m['id'] == 'bank');
                  if (bankIdx != -1) {
                    _methods[bankIdx]['active'] = true;
                    _methods[bankIdx]['details'] = '${_bankNameController.text} A/C: ${_accountNumberController.text}';
                  }
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply Details'),
          ),
        ],
      ),
    );
  }

  void _showCashDetailsDialog() {
    final timingsCtrl = TextEditingController(text: _cashTimingsController.text);
    final instructionsCtrl = TextEditingController(text: _cashInstructionsController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Cash Counter Settings'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: timingsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reception / Desk Timings',
                  hintText: 'e.g. 8:00 AM – 10:00 PM (Daily)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Desk Instructions for Students',
                  hintText: 'e.g. Visit reception counter. Instant receipts given.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _cashTimingsController.text = timingsCtrl.text.trim();
                _cashInstructionsController.text = instructionsCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showChequeDetailsDialog() {
    final payeeCtrl = TextEditingController(text: _chequePayeeController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Cheque / DD Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: payeeCtrl,
              decoration: const InputDecoration(
                labelText: 'Cheque in Favour Of *',
                hintText: 'e.g. The Cozy Corner Centre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_rounded),
                helperText: 'Name that students should write on cheques',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _chequePayeeController.text = payeeCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({int? index}) {
    final isEditing = index != null;
    final current = isEditing ? _methods[index] : null;

    final nameController = TextEditingController(text: current?['name'] ?? '');
    final detailsController = TextEditingController(text: current?['details'] ?? '');
    bool isActive = current?['active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Payment Method' : 'Add Payment Method'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Method Name (e.g. POS Card, Paytm Wallet)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions / Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _methods.removeAt(index));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final item = {
                  'id': isEditing ? current!['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': name,
                  'details': detailsController.text.trim(),
                  'active': isActive,
                };

                setState(() {
                  if (isEditing) {
                    _methods[index] = item;
                  } else {
                    _methods.add(item);
                  }
                });

                Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _onEditMethod(int index) {
    final method = _methods[index];
    final id = method['id']?.toString().toLowerCase() ?? '';

    if (id == 'bank') {
      _showBankDetailsDialog();
    } else if (id == 'cash') {
      _showCashDetailsDialog();
    } else if (id == 'cheque') {
      _showChequeDetailsDialog();
    } else {
      _showAddEditDialog(index: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUpi = _upiIdController.text.trim();
    final currentPayee = _payeeNameController.text.trim();
    final upiVpaRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    final isUpiValid = currentUpi.isNotEmpty && upiVpaRegex.hasMatch(currentUpi);
    final mccVal = _mccController.text.trim().isNotEmpty ? _mccController.text.trim() : '8299';
    final previewUri = _accountType == 'merchant'
        ? 'upi://pay?pa=$currentUpi&pn=${Uri.encodeComponent(currentPayee)}&mc=$mccVal&cu=INR'
        : 'upi://pay?pa=$currentUpi&pn=${Uri.encodeComponent(currentPayee)}&cu=INR';

    final hasBankDetails = _bankNameController.text.isNotEmpty && _accountNumberController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment & Billing Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save All'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  padding: const EdgeInsets.all(16),
              children: [
                // 1. Library UPI & QR Settings Card (Collapsible)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _upiExpanded = !_upiExpanded),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.qr_code_2_rounded, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Library UPI ID & QR Code',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      currentUpi.isNotEmpty
                                          ? 'Active UPI: $currentUpi'
                                          : 'Used for student membership renewals & instant payments',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _upiExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                        if (_upiExpanded) ...[
                          const SizedBox(height: 16),

                          // UPI ID Field
                        TextField(
                          controller: _upiIdController,
                          decoration: InputDecoration(
                            labelText: 'Library UPI ID / VPA *',
                            hintText: 'e.g. library@upi or cozycorner@okaxis',
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                            border: const OutlineInputBorder(),
                            errorText: (currentUpi.isNotEmpty && !isUpiValid)
                                ? 'Invalid UPI VPA format (e.g. library@bank or 9876543210@upi)'
                                : null,
                            helperText: 'Google Pay, PhonePe, Paytm, BHIM registered UPI ID',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: 'Copy UPI ID',
                              onPressed: () {
                                final text = _upiIdController.text.trim();
                                if (text.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('UPI ID copied to clipboard!')),
                                  );
                                }
                              },
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),

                        // Payee Name Field
                        TextField(
                          controller: _payeeNameController,
                          decoration: const InputDecoration(
                            labelText: 'Merchant / Payee Name *',
                            hintText: 'e.g. Study Library Center',
                            prefixIcon: Icon(Icons.business_rounded),
                            border: OutlineInputBorder(),
                            helperText: 'Business name shown on student banking & UPI apps',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),

                        // Merchant Phone Field
                        TextField(
                          controller: _upiPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Merchant WhatsApp / Mobile Number',
                            hintText: 'e.g. 9876543210',
                            prefixIcon: Icon(Icons.phone_rounded),
                            border: OutlineInputBorder(),
                            helperText: 'Students can share renewal payment screenshot directly to this number',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── UPI Tier & Account Type (P2P vs P2M Merchant) ──
                        const Text(
                          'UPI Account Type & Limit Tier',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'p2p',
                              label: Text('Personal Savings (P2P)'),
                              icon: Icon(Icons.person_outline_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: 'merchant',
                              label: Text('Business Merchant (P2M)'),
                              icon: Icon(Icons.verified_rounded, size: 16),
                            ),
                          ],
                          selected: {_accountType},
                          onSelectionChanged: (val) => setState(() => _accountType = val.first),
                        ),
                        const SizedBox(height: 10),

                        if (_accountType == 'p2p')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'NPCI ₹2,000 Web Deep Link Rule Active',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Banks cap pre-filled deep links at ₹2,000 for personal savings UPI IDs. For student plans > ₹2,000, our system automatically activates Smart Assisted Intent (Payee pre-filled, student enters amount) so payments never fail.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF047857)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Verified Merchant (P2M) Active: Dynamic QRs & deep links support up to ₹1,00,000+ with pre-filled amounts without bank link limits.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _mccController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Merchant Category Code (MCC)',
                              hintText: '8299',
                              prefixIcon: Icon(Icons.category_outlined),
                              border: OutlineInputBorder(),
                              helperText: 'Default 8299 = Educational / Coaching / Library Services',
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Collapsible Merchant Upgrade Guide
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Theme(
                            data: theme.copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: _merchantGuideExpanded,
                              onExpansionChanged: (exp) => setState(() => _merchantGuideExpanded = exp),
                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              leading: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 20),
                              title: const Text(
                                'How to get a FREE Business Merchant QR (No ₹2,000 limit)',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'To allow students to pay any amount (₹3,800, ₹7,200, ₹15,000) in 1 tap without any bank limit errors:',
                                        style: TextStyle(fontSize: 11.5, height: 1.35),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '1. Install Google Pay for Business, PhonePe Business, or Paytm for Business on your phone.',
                                        style: TextStyle(fontSize: 11.5, height: 1.3),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '2. Register using your Aadhaar/PAN & Bank Account (Takes 3 minutes, 100% free, 0% commission on UPI).',
                                        style: TextStyle(fontSize: 11.5, height: 1.3),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '3. Set category to "Education / Coaching / Library" (MCC 8299).',
                                        style: TextStyle(fontSize: 11.5, height: 1.3),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '4. Copy your Merchant UPI ID (e.g. cozycorner@okbizaxis) and paste it into the Library UPI ID field above, then select "Business Merchant (P2M)".',
                                        style: TextStyle(fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Live QR Preview
                        if (currentUpi.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: QrImageView(
                                    data: previewUri,
                                    version: QrVersions.auto,
                                    size: 80.0,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                          SizedBox(width: 4),
                                          Text('Live Dynamic QR Ready', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentUpi,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Text(
                                        currentPayee,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Students scanning this QR will directly pay to your library account.',
                                        style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Direct Bank Transfer (NEFT / IMPS) Card (Collapsible)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _bankExpanded = !_bankExpanded),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00796B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.account_balance_rounded, color: Color(0xFF00796B)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Direct Bank Account (NEFT / IMPS)',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      hasBankDetails
                                          ? '${_bankNameController.text} (•••• ${_accountNumberController.text.length > 4 ? _accountNumberController.text.substring(_accountNumberController.text.length - 4) : _accountNumberController.text})'
                                          : 'Official library account details for student direct bank transfers',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: hasBankDetails ? const Color(0xFF00796B) : theme.colorScheme.outline,
                                        fontWeight: hasBankDetails ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _showBankDetailsDialog,
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: Text(hasBankDetails ? 'Edit' : 'Configure'),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _bankExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                        if (_bankExpanded) ...[
                          const SizedBox(height: 14),

                        if (hasBankDetails) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Bank Name', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        Text(_bankNameController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Account Holder', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        Text(_accountHolderController.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Account Number', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        Text(_accountNumberController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      tooltip: 'Copy Account Number',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: _accountNumberController.text));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Account number copied!')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('IFSC Code', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        Text(_ifscCodeController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (_branchController.text.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: Text('(${_branchController.text})', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 18),
                                          tooltip: 'Copy IFSC',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: _ifscCodeController.text));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('IFSC code copied!')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.amber.shade800),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No bank account configured yet. Add your bank account so students can pay via direct NEFT / IMPS.',
                                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: _showBankDetailsDialog,
                                  child: const Text('Add Bank'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Accepted Payment Modes Section (Collapsible Card Container)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _methodsExpanded = !_methodsExpanded),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.payments_rounded, color: Color(0xFF0D9488)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Accepted Payment Methods',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${_methods.where((m) => m['active'] == true).length} active methods enabled for students & reception',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add'),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _methodsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                        if (_methodsExpanded) ...[
                          const SizedBox(height: 14),

                // Payment Methods List
                ..._methods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final method = entry.value;
                  final isActive = method['active'] == true;
                  final id = method['id']?.toString().toLowerCase() ?? '';

                  return Card(
                    key: ValueKey(method['id']),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          id == 'upi'
                              ? Icons.qr_code_rounded
                              : id == 'cash'
                                  ? Icons.storefront_rounded
                                  : id == 'card'
                                      ? Icons.credit_card_rounded
                                      : id == 'bank'
                                          ? Icons.account_balance_rounded
                                          : id == 'cheque'
                                              ? Icons.receipt_long_rounded
                                              : Icons.payments_rounded,
                          color: isActive ? theme.colorScheme.primary : Colors.grey,
                        ),
                      ),
                      title: Text(
                        method['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? theme.colorScheme.onSurface : Colors.grey,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (id == 'bank') ...[
                            Text(
                              hasBankDetails
                                  ? 'Bank: ${_bankNameController.text} • A/C: •••• ${_accountNumberController.text.length > 4 ? _accountNumberController.text.substring(_accountNumberController.text.length - 4) : _accountNumberController.text}'
                                  : '⚠️ No bank account configured yet (Tap edit to configure)',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasBankDetails
                                    ? (isActive ? Colors.grey.shade800 : Colors.grey)
                                    : Colors.amber.shade900,
                                fontWeight: hasBankDetails ? FontWeight.w500 : FontWeight.bold,
                              ),
                            ),
                          ] else if (id == 'cash') ...[
                            Text(
                              'Desk Hours: ${_cashTimingsController.text}',
                              style: TextStyle(fontSize: 12, color: isActive ? Colors.grey.shade800 : Colors.grey),
                            ),
                          ] else if (id == 'cheque') ...[
                            Text(
                              _chequePayeeController.text.isNotEmpty
                                  ? 'In Favour Of: ${_chequePayeeController.text}'
                                  : 'Cheque in favour of library',
                              style: TextStyle(fontSize: 12, color: isActive ? Colors.grey.shade800 : Colors.grey),
                            ),
                          ] else if (id == 'upi') ...[
                            Text(
                              _upiPhoneController.text.isNotEmpty
                                  ? 'UPI: $currentUpi • Mobile: ${_upiPhoneController.text}'
                                  : 'UPI: $currentUpi',
                              style: TextStyle(fontSize: 12, color: isActive ? Colors.grey.shade800 : Colors.grey),
                            ),
                          ] else if (method['details']?.toString().isNotEmpty == true) ...[
                            Text(
                              method['details'],
                              style: TextStyle(fontSize: 12, color: isActive ? Colors.grey.shade700 : Colors.grey),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (v) => _toggleMethod(index, v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            tooltip: 'Configure / Edit method',
                            onPressed: () => _onEditMethod(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Payment Policies & Billing Card (Collapsible)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _policiesExpanded = !_policiesExpanded),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.policy_rounded, color: Colors.indigo),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Renewal Policies & Billing Details',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Grace period (${_gracePeriodController.text}d), late fine, GSTIN & refund rules',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _policiesExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                        if (_policiesExpanded) ...[
                          const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _gracePeriodController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Grace Period (Days)',
                                  hintText: '3',
                                  prefixIcon: Icon(Icons.timelapse_rounded),
                                  border: OutlineInputBorder(),
                                  helperText: 'Days after expiry before seat is released',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _lateFineController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Late Fine (₹ / Day)',
                                  hintText: '0',
                                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                                  border: OutlineInputBorder(),
                                  helperText: 'Optional late fee per overdue day',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: _gstinController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'GSTIN / Tax ID (Optional)',
                            hintText: 'e.g. 27AAAAA0000A1Z5',
                            prefixIcon: Icon(Icons.receipt_rounded),
                            border: OutlineInputBorder(),
                            helperText: 'Printed on official fee receipts if registered',
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: _refundPolicyController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Refund & Cancellation Policy',
                            hintText: 'e.g. Fees once paid are non-refundable...',
                            prefixIcon: Icon(Icons.article_outlined),
                            border: OutlineInputBorder(),
                            helperText: 'Shown to students during plan renewal and on receipts',
                          ),
                        ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
    );
  }
}
