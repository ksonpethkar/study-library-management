import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/id_card_template_model.dart';
import 'package:study_library/services/id_card_pdf_service.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/features/settings/presentation/screens/id_card_customizer_screen.dart';

class IdCardPreviewScreen extends ConsumerStatefulWidget {
  final StudentModel student;
  final String? seatLabel;
  final String? sectionName;
  final String? planName;

  const IdCardPreviewScreen({
    super.key,
    required this.student,
    this.seatLabel,
    this.sectionName,
    this.planName,
  });

  @override
  ConsumerState<IdCardPreviewScreen> createState() => _IdCardPreviewScreenState();
}

class _IdCardPreviewScreenState extends ConsumerState<IdCardPreviewScreen> {
  IdCardPrintFormat _format = IdCardPrintFormat.a4CutAndFold;

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(currentLibraryProvider);
    final templateAsync = ref.watch(idCardTemplateProvider);
    final library = libraryAsync.value;
    final settings = templateAsync.value ?? const IdCardTemplateSettings();

    if (library == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Digital Student ID Card')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.student.name} — ID Card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Customize Card Elements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IdCardCustomizerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share via WhatsApp',
            onPressed: () async {
              final whatsapp = ref.read(whatsappServiceProvider);
              final message = 'Hello ${widget.student.name}, here is your official Student ID Card for ${library.name}. Please carry it daily for entry.';
              await whatsapp.sendMessage(widget.student.phone, message);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SegmentedButton<IdCardPrintFormat>(
                  segments: const [
                    ButtonSegment(
                      value: IdCardPrintFormat.a4CutAndFold,
                      icon: Icon(Icons.content_cut_rounded, size: 16),
                      label: Text('A4 (Cut & Fold 1-Page)', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: IdCardPrintFormat.cr80Direct,
                      icon: Icon(Icons.credit_card_rounded, size: 16),
                      label: Text('CR80 (Card Printer)', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {_format},
                  onSelectionChanged: (newSelection) {
                    setState(() => _format = newSelection.first);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (pageFormat) async {
                return await IdCardPdfService.generateIdCard(
                  student: widget.student,
                  library: library,
                  seatLabel: widget.seatLabel,
                  sectionName: widget.sectionName,
                  planName: widget.planName,
                  settings: settings,
                  format: _format,
                );
              },
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: 'ID_Card_${widget.student.name.replaceAll(' ', '_')}.pdf',
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.tune),
                  onPressed: (ctx, build, pageFormat) {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (_) => const IdCardCustomizerScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
