import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:study_library/core/utils/pdf_helper.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app PDF viewer that rasterizes PDF pages client-side (supporting both
/// Base64 data URLs and network URLs) and prompts for a password if the PDF
/// is encrypted (such as UIDAI e-Aadhaar PDFs).
class InAppPdfViewer extends StatefulWidget {
  final String pdfUrlOrDataUrl;
  final String? title;
  final bool compact;

  const InAppPdfViewer({
    super.key,
    required this.pdfUrlOrDataUrl,
    this.title,
    this.compact = false,
  });

  @override
  State<InAppPdfViewer> createState() => _InAppPdfViewerState();
}

class _InAppPdfViewerState extends State<InAppPdfViewer> {
  final TextEditingController _passwordCtrl = TextEditingController();
  Uint8List? _pdfBytes;
  List<Uint8List> _pageImages = [];
  bool _loading = true;
  bool _needsPassword = false;
  bool _incorrectPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void didUpdateWidget(covariant InAppPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfUrlOrDataUrl != widget.pdfUrlOrDataUrl) {
      _passwordCtrl.clear();
      _loadPdf();
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPdf({String? password}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _incorrectPassword = false;
    });

    try {
      Uint8List? bytes = _pdfBytes;
      if (bytes == null) {
        final src = widget.pdfUrlOrDataUrl.trim();
        if (src.startsWith('data:')) {
          final b64 = src.contains(',') ? src.split(',')[1] : src;
          bytes = base64Decode(b64);
        } else {
          final resp = await http.get(Uri.parse(src));
          if (resp.statusCode < 200 || resp.statusCode >= 300) {
            throw Exception('HTTP ${resp.statusCode} while fetching PDF');
          }
          bytes = resp.bodyBytes;
        }
        _pdfBytes = bytes;
      }

      // If no password supplied yet, try standard Printing.raster first.
      if (password == null || password.isEmpty) {
        try {
          final pages = <Uint8List>[];
          await for (final page in Printing.raster(bytes, dpi: 150)) {
            pages.add(await page.toPng());
            if (pages.length >= 5) break; // Cap preview at 5 pages
          }
          if (pages.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _pageImages = pages;
              _needsPassword = false;
              _loading = false;
            });
            return;
          }
        } catch (_) {
          // Fall through to PdfHelper (handles passworded PDFs & Web PDF.js).
        }
      }

      final rasterResult = await PdfHelper.renderFirstPageAsJpeg(
        bytes,
        password: password,
        dpi: 150,
      );

      if (!mounted) return;

      if (rasterResult.passwordRequired || rasterResult.incorrectPassword) {
        setState(() {
          _needsPassword = true;
          _incorrectPassword = rasterResult.incorrectPassword;
          _loading = false;
        });
        return;
      }

      if (rasterResult.jpegBytes != null) {
        setState(() {
          _pageImages = [rasterResult.jpegBytes!];
          _needsPassword = false;
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = rasterResult.errorMessage ?? 'Unable to render PDF preview.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load PDF: $e';
        _loading = false;
      });
    }
  }

  Future<void> _downloadOrSharePdf() async {
    final bytes = _pdfBytes;
    if (bytes != null) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${(widget.title ?? 'document').replaceAll(' ', '_')}.pdf',
      );
      return;
    }
    final uri = Uri.tryParse(widget.pdfUrlOrDataUrl);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Rendering PDF preview...',
                style: TextStyle(
                  color: widget.compact ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_needsPassword) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.amber.withValues(alpha: 0.45)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: Colors.amber, size: 36),
                  const SizedBox(height: 10),
                  const Text(
                    'Password-Protected PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter PDF password to preview (e.g. e-Aadhaar: first 4 letters of name in CAPS + birth year).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter PDF password',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      errorText: _incorrectPassword
                          ? 'Incorrect password. Please try again.'
                          : null,
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (val) => _loadPdf(password: val.trim()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _loadPdf(password: _passwordCtrl.text.trim()),
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Unlock & View'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_error != null || _pageImages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_rounded,
                  size: 56, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _error ?? 'PDF preview unavailable.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _downloadOrSharePdf,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download / Open PDF'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _pageImages.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _pageImages[i],
                fit: BoxFit.contain,
              ),
            ),
          ],
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pageImages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Column(
          children: [
            if (_pageImages.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Page ${index + 1} of ${_pageImages.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _pageImages[index],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
