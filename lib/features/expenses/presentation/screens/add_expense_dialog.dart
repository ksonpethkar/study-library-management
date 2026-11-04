import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/features/expenses/presentation/providers/expense_providers.dart';
import 'package:study_library/models/expense_model.dart';
import 'package:study_library/services/ocr_service.dart';
import 'package:study_library/services/expense_ocr_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class AddExpenseDialog extends ConsumerStatefulWidget {
  final ExpenseModel? existingExpense;
  final bool isSheet;

  const AddExpenseDialog({super.key, this.existingExpense, this.isSheet = false});

  static Future<void> show(BuildContext context, {ExpenseModel? expense}) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddExpenseDialog(existingExpense: expense, isSheet: true),
      );
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddExpenseDialog(existingExpense: expense, isSheet: false),
    );
  }

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _paidToController;
  late final TextEditingController _notesController;

  late ExpenseCategory _selectedCategory;
  late String _selectedPaymentMethod;
  late DateTime _selectedDate;
  bool _isLoading = false;
  bool _isScanningBill = false;

  static const List<String> _paymentMethods = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Card'];

  @override
  void initState() {
    super.initState();
    final ex = widget.existingExpense;
    _titleController = TextEditingController(text: ex?.title ?? '');
    _amountController = TextEditingController(text: ex != null ? ex.amount.toStringAsFixed(0) : '');
    _paidToController = TextEditingController(text: ex?.paidTo ?? '');
    _notesController = TextEditingController(text: ex?.notes ?? '');

    _selectedCategory = ex?.category ?? ExpenseCategory.electricity;
    _selectedPaymentMethod = ex?.paymentMethod ?? 'Cash';
    _selectedDate = ex?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _paidToController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _scanBillReceipt() async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Bill or Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                title: const Text('Choose from Gallery / Files'),
                subtitle: const Text('Pick bill photo, PDF screenshot, or invoice image'),
                onTap: () async {
                  final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
                  if (ctx.mounted) Navigator.pop(ctx, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.green),
                title: const Text('Take Photo with Camera'),
                subtitle: const Text('Photograph paper bill or meter slip'),
                onTap: () async {
                  final file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600);
                  if (ctx.mounted) Navigator.pop(ctx, file);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => _isScanningBill = true);
    try {
      final bytes = await picked.readAsBytes();
      final ocrService = OcrService();
      final rawText = await ocrService.processImageBytes(bytes);
      final result = ExpenseOcrParser.parse(rawText);

      if (!mounted) return;

      if (result.hasValidData) {
        if (result.amount != null && result.amount! > 0) {
          _amountController.text = result.amount!.toStringAsFixed(0);
        }
        if (result.vendorName != null && result.vendorName!.isNotEmpty) {
          _paidToController.text = result.vendorName!;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = '${result.suggestedCategory.displayName} - ${result.vendorName!}';
          }
        }
        if (result.date != null) {
          _selectedDate = result.date!;
        }
        setState(() {
          _selectedCategory = result.suggestedCategory;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extracted: ₹${result.amount?.toStringAsFixed(0) ?? ""} for ${result.suggestedCategory.displayName}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract bill details automatically. Please enter manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'camera');
      }
    } finally {
      if (mounted) setState(() => _isScanningBill = false);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active library selected')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

      final expense = ExpenseModel(
        id: widget.existingExpense?.id ?? '',
        libraryId: libraryId,
        title: _titleController.text.trim(),
        category: _selectedCategory,
        amount: amount,
        date: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        paidTo: _paidToController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: widget.existingExpense?.createdAt ?? DateTime.now(),
      );

      if (widget.existingExpense != null) {
        await repo.updateExpense(libraryId, expense);
      } else {
        await repo.addExpense(libraryId, expense);
      }

      ref.invalidate(expensesStreamProvider);
      ref.invalidate(netProfitProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingExpense != null ? 'Expense updated' : 'Expense recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'expense');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');
    final isNarrow = MediaQuery.of(context).size.width < 400;

    final formContent = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existingExpense != null ? 'Edit Expense' : 'Record Operating Expense',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // OCR Scan Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isScanningBill ? null : _scanBillReceipt,
              icon: _isScanningBill
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.document_scanner_rounded, size: 18),
              label: Text(_isScanningBill ? 'Analyzing Bill with OCR...' : 'Auto-Fill from Bill / Invoice (OCR)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Expense Title *',
              hintText: 'e.g. Electricity Bill Oct, Wi-Fi Recharge',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
            validator: (v) => AppValidators.required(v, label: 'Expense title'),
          ),
          const SizedBox(height: 16),

          // Category Dropdown
          DropdownButtonFormField<ExpenseCategory>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Expense Category *',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: ExpenseCategory.values.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Row(
                  children: [
                    Text(cat.iconEmoji),
                    const SizedBox(width: 8),
                    Text(cat.displayName),
                  ],
                ),
              );
            }).toList(),
            onChanged: (cat) {
              if (cat != null) setState(() => _selectedCategory = cat);
            },
          ),
          const SizedBox(height: 16),

          // Amount
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: AppValidators.amountFormatters,
            decoration: const InputDecoration(
              labelText: 'Amount (₹) *',
              hintText: 'e.g. 1500',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
            validator: (v) => AppValidators.amount(v, min: 1, max: 500000),
          ),
          const SizedBox(height: 16),

          // Date Picker & Payment Method (Responsive Stack on narrow screens)
          if (isNarrow) ...[
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(dateFormat.format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedPaymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                prefixIcon: Icon(Icons.payments_outlined, size: 18),
              ),
              items: _paymentMethods.map((m) {
                return DropdownMenuItem(value: m, child: Text(m));
              }).toList(),
              onChanged: (m) {
                if (m != null) setState(() => _selectedPaymentMethod = m);
              },
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                      child: Text(dateFormat.format(_selectedDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      prefixIcon: Icon(Icons.payments_outlined, size: 18),
                    ),
                    items: _paymentMethods.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (m) {
                      if (m != null) setState(() => _selectedPaymentMethod = m);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Paid To
          TextFormField(
            controller: _paidToController,
            decoration: const InputDecoration(
              labelText: 'Paid To / Vendor Name',
              hintText: 'e.g. MSEDCL, Airtel, Ramesh Kumar',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes / Remarks (Optional)',
              hintText: 'Reference bill number or details',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _saveExpense,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(widget.existingExpense != null ? 'Update Expense' : 'Record Expense'),
            ),
          ),
        ],
      ),
    );

    if (widget.isSheet) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: formContent,
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: formContent,
        ),
      ),
    );
  }
}
