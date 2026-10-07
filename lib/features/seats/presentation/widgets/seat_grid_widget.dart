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

  const SeatGridWidget({
    super.key,
    required this.libraryId,
    required this.sectionId,
    required this.rows,
    required this.cols,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(seatsProvider(sectionId));
    final selectedSeats = ref.watch(selectedSeatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildLegendItem(Colors.green, 'Available'),
            _buildLegendItem(Colors.red, 'Occupied'),
            _buildLegendItem(Colors.amber, 'Reserved'),
            _buildLegendItem(Colors.grey, 'Maintenance'),
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
