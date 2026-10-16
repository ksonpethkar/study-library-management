import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/seat_providers.dart';
import 'seat_tile.dart';
import 'seat_detail_sheet.dart';

import 'package:study_library/models/seat_model.dart';

class SeatGridWidget extends ConsumerWidget {
  final String libraryId;
  final String sectionId;
  final int rows;
  final int cols;
  final int? sectionColor;

  const SeatGridWidget({
    super.key,
    required this.libraryId,
    required this.sectionId,
    required this.rows,
    required this.cols,
    this.sectionColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(seatsProvider(sectionId));
    final selectedSeats = ref.watch(selectedSeatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legend with matching tile backgrounds and borders
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildLegendItem(
              isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9),
              isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
              'Available',
            ),
            _buildLegendItem(
              isDark ? const Color(0xFF3E1D24) : const Color(0xFFFFEBEE),
              isDark ? const Color(0xFFC62828) : const Color(0xFFEF9A9A),
              'Occupied',
            ),
            _buildLegendItem(
              isDark ? const Color(0xFF3E3218) : const Color(0xFFFFF8E1),
              isDark ? const Color(0xFFF57F17) : const Color(0xFFFFD54F),
              'Reserved',
            ),
            _buildLegendItem(
              isDark ? const Color(0xFF2B2B2B) : const Color(0xFFEEEEEE),
              isDark ? const Color(0xFF616161) : const Color(0xFFBDBDBD),
              'Maintenance',
            ),
          ],
        ),
        const SizedBox(height: 16),
        seatsAsync.when(
          data: (seats) {
            if (seats.isEmpty) {
              return const Center(child: Text('No seats initialized.'));
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: rows * cols,
                  itemBuilder: (context, index) {
                    final r = index ~/ cols;
                    final c = index % cols;

                    final seat = seats.firstWhere(
                      (s) => s.row == r && s.col == c,
                      orElse: () => SeatModel(
                        id: 'missing_${r}_$c',
                        sectionId: sectionId,
                        label: '-',
                        row: r,
                        col: c,
                        status:
                            SeatStatus.reserved, // shows as unavailable/grey
                        genderRestriction: GenderRestriction.any,
                      ),
                    );

                    final isMissing = seat.id.startsWith('missing_');
                    final isSelected = selectedSeats.containsKey(seat.id);

                    return SeatTile(
                      seat: seat,
                      isSelected: isSelected,
                      sectionColor: sectionColor != null ? Color(sectionColor!) : null,
                      onTap: () {
                        if (isMissing) return;
                        if (selectedSeats.isNotEmpty) {
                          ref
                              .read(selectedSeatsProvider.notifier)
                              .toggleSelection(seat.id, sectionId);
                        } else {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => SeatDetailSheet(
                              seat: seat,
                              sectionId: sectionId,
                            ),
                          );
                        }
                      },
                      onLongPress: () {
                        if (isMissing) return;
                        ref
                            .read(selectedSeatsProvider.notifier)
                            .toggleSelection(seat.id, sectionId);
                      },
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Error loading seats: $err')),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color bgColor, Color borderColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
