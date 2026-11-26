import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:study_library/services/image_service.dart';

/// Official certified organisational rubber stamp / seal stamp widget.
/// Renders an authentic double-ring institutional seal stamp on student ID passes,
/// receipts, and credentials, reflecting library branding and active/inactive state.
class OrganisationalSealStamp extends StatelessWidget {
  final String libraryName;
  final String? locality;
  final String? stampUrl;
  final double size;
  final Color? inkColor;
  final bool isInactive;
  final double rotation;

  const OrganisationalSealStamp({
    super.key,
    required this.libraryName,
    this.locality,
    this.stampUrl,
    this.size = 48.0,
    this.inkColor,
    this.isInactive = false,
    this.rotation = -7.0,
  });

  @override
  Widget build(BuildContext context) {
    // If a custom stamp image is uploaded, render it with slight rotation
    if (stampUrl != null && stampUrl!.trim().isNotEmpty) {
      final imgProvider = ImageService.getImageProvider(stampUrl!.trim());
      if (imgProvider != null) {
        return Transform.rotate(
          angle: rotation * (math.pi / 180),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image(
                image: imgProvider,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildVectorStamp(context),
              ),
            ),
          ),
        );
      }
    }

    // Otherwise render the authentic procedural rubber seal stamp
    return Transform.rotate(
      angle: rotation * (math.pi / 180),
      child: _buildVectorStamp(context),
    );
  }

  Widget _buildVectorStamp(BuildContext context) {
    final effectiveInk = isInactive
        ? const Color(0xFFEF4444)
        : (inkColor ?? const Color(0xFF38BDF8));

    final shortName = libraryName.trim().isNotEmpty
        ? libraryName.trim().toUpperCase()
        : 'COZY CORNER';
    final loc = (locality != null && locality!.trim().isNotEmpty)
        ? locality!.trim().toUpperCase()
        : 'PARLI VAIJNATH';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveInk.withValues(alpha: 0.08),
        border: Border.all(color: effectiveInk.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: effectiveInk.withValues(alpha: 0.12),
            blurRadius: 3,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: effectiveInk.withValues(alpha: 0.5), width: 0.8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Arc Text / Acronym
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Text(
                      shortName.length > 14 ? '${shortName.substring(0, 12)}..' : shortName,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: size * 0.11,
                        fontWeight: FontWeight.w900,
                        color: effectiveInk,
                        letterSpacing: 0.3,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size * 0.03),

                // Center Core Emblem / Status
                if (isInactive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: effectiveInk.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: effectiveInk, width: 0.8),
                    ),
                    child: Text(
                      'INACTIVE',
                      style: TextStyle(
                        fontSize: size * 0.14,
                        fontWeight: FontWeight.w900,
                        color: effectiveInk,
                        letterSpacing: 0.5,
                        height: 1.0,
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: size * 0.16, color: effectiveInk),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.0),
                        child: Text(
                          'SEAL',
                          style: TextStyle(
                            fontSize: size * 0.15,
                            fontWeight: FontWeight.w900,
                            color: effectiveInk,
                            letterSpacing: 0.6,
                            height: 1.0,
                          ),
                        ),
                      ),
                      Icon(Icons.star_rounded, size: size * 0.16, color: effectiveInk),
                    ],
                  ),
                  SizedBox(height: size * 0.02),
                  Text(
                    'APPROVED',
                    style: TextStyle(
                      fontSize: size * 0.11,
                      fontWeight: FontWeight.bold,
                      color: effectiveInk.withValues(alpha: 0.9),
                      letterSpacing: 0.4,
                      height: 1.0,
                    ),
                  ),
                ],
                SizedBox(height: size * 0.03),

                // Bottom Locality Arc
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: Text(
                      isInactive ? 'VOID' : loc,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: size * 0.10,
                        fontWeight: FontWeight.w800,
                        color: effectiveInk.withValues(alpha: 0.85),
                        letterSpacing: 0.3,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
