import 'package:flutter_test/flutter_test.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/models/seat_model.dart';

void main() {
  group('SeatHelper Natural Sequential Sorting Tests', () {
    test('1. Resolves screenshot issue: 2 must sort before 12..21', () {
      final input = ['12', '13', '14', '15', '16', '17', '18', '19', '2', '20', '21'];
      input.sort(SeatHelper.compareNatural);

      expect(input, ['2', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21']);
    });

    test('2. Naturally sorts complete 1..25 sequence without lexicographical bugs', () {
      final input = [
        '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
        '1', '2', '20', '21', '22', '23', '24', '25', '3', '4', '5', '6', '7', '8', '9'
      ];
      input.sort(SeatHelper.compareNatural);

      final expected = List.generate(25, (i) => '${i + 1}');
      expect(input, expected);
    });

    test('3. Naturally sorts alphanumeric grid seats (A1, A2, ... A10, B1, B2)', () {
      final input = ['A12', 'A2', 'B1', 'A1', 'B10', 'A10', 'B2'];
      input.sort(SeatHelper.compareNatural);

      expect(input, ['A1', 'A2', 'A10', 'A12', 'B1', 'B2', 'B10']);
    });

    test('4. Naturally sorts prefixed seat labels (Seat #1, Seat #2, Seat #10...)', () {
      final input = ['Seat #19', 'Seat #2', 'Seat #20', 'Seat #1', 'Seat #10'];
      input.sort(SeatHelper.compareNatural);

      expect(input, ['Seat #1', 'Seat #2', 'Seat #10', 'Seat #19', 'Seat #20']);
    });

    test('5. Naturally sorts custom prefix cabins (CAB-01, CAB-02, CAB-10...)', () {
      final input = ['CAB-02', 'CAB-12', 'CAB-01', 'CAB-10'];
      input.sort(SeatHelper.compareNatural);

      expect(input, ['CAB-01', 'CAB-02', 'CAB-10', 'CAB-12']);
    });

    test('6. Compares SeatModel instances seamlessly by natural label and row/col', () {
      final seats = [
        SeatModel(id: 's12', sectionId: 'sec1', row: 1, col: 1, label: '12', status: SeatStatus.available, genderRestriction: GenderRestriction.any),
        SeatModel(id: 's2', sectionId: 'sec1', row: 0, col: 1, label: '2', status: SeatStatus.available, genderRestriction: GenderRestriction.any),
        SeatModel(id: 's1', sectionId: 'sec1', row: 0, col: 0, label: '1', status: SeatStatus.available, genderRestriction: GenderRestriction.any),
        SeatModel(id: 's20', sectionId: 'sec1', row: 1, col: 9, label: '20', status: SeatStatus.available, genderRestriction: GenderRestriction.any),
      ];

      seats.sort(SeatHelper.compareSeats);

      expect(seats.map((s) => s.label).toList(), ['1', '2', '12', '20']);
    });

    test('7. Compares seat map entries seamlessly for export previews and CSV', () {
      final maps = [
        {'id': '12', 'sectionId': 'hall_a', 'label': '12'},
        {'id': '2', 'sectionId': 'hall_a', 'label': '2'},
        {'id': '19', 'sectionId': 'hall_a', 'label': '19'},
        {'id': '1', 'sectionId': 'hall_a', 'label': '1'},
        {'id': '20', 'sectionId': 'hall_a', 'label': '20'},
      ];

      maps.sort(SeatHelper.compareSeatMaps);

      expect(maps.map((m) => m['label']).toList(), ['1', '2', '12', '19', '20']);
    });
  });
}
