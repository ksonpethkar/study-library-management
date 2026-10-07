class AadhaarValidator {
  static final List<List<int>> _d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  ];

  static final List<List<int>> _p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8]
  ];

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an Aadhaar number.';
    }

    final cleanValue = value.replaceAll(RegExp(r'\s+'), '');

    if (cleanValue.length != 12) {
      return 'Please enter a valid 12-digit Aadhaar number.';
    }

    if (!RegExp(r'^\d{12}$').hasMatch(cleanValue)) {
      return 'Aadhaar number should only contain numbers.';
    }

    if (!_validateVerhoeff(cleanValue)) {
      return 'Please enter a valid Aadhaar number.';
    }

    return null;
  }

  static bool _validateVerhoeff(String numStr) {
    int c = 0;
    List<int> myArray = numStr.split('').map(int.parse).toList();
    List<int> reversed = myArray.reversed.toList();

    for (int i = 0; i < reversed.length; i++) {
      c = _d[c][_p[(i % 8)][reversed[i]]];
    }
    return (c == 0);
  }
}
