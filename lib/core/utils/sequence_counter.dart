import 'package:cloud_firestore/cloud_firestore.dart';

/// Generates sequential, atomic IDs using Firestore transactions.
/// Counter document: libraries/{libraryId}/settings/counters
/// Fields: receiptCounter (int), studentCounter (int)
class SequenceCounter {
  /// Returns the next sequential receipt number as a zero-padded string.
  /// Format: REC-0001, REC-0002, ...
  static Future<String> nextReceiptNumber(String libraryId) async {
    final counterRef = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('counters');
    
    int nextNum = 1;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['receiptCounter'] as int?) ?? 0;
      nextNum = current + 1;
      if (snap.exists) {
        tx.update(counterRef, {'receiptCounter': nextNum});
      } else {
        tx.set(counterRef, {'receiptCounter': nextNum, 'studentCounter': 0});
      }
    });
    
    return 'REC-${nextNum.toString().padLeft(4, '0')}';
  }
  
  /// Returns the next sequential student membership number.
  /// Format: {prefix}YYYY0001 e.g. CC20260001
  static Future<String> nextMembershipNumber(String libraryId, {String prefix = 'CC'}) async {
    final batch = await nextMembershipNumberBatch(libraryId, count: 1, prefix: prefix);
    return batch.isNotEmpty ? batch.first : '$prefix${DateTime.now().year}0001';
  }

  /// Atomically reserves a block of [count] consecutive student membership numbers.
  /// Returns the list of generated IDs.
  static Future<List<String>> nextMembershipNumberBatch(
    String libraryId, {
    required int count,
    String prefix = 'CC',
  }) async {
    if (count <= 0) return [];
    final counterRef = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('counters');

    int startNum = 1;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['studentCounter'] as int?) ?? 0;
      startNum = current + 1;
      final newTotal = current + count;
      if (snap.exists) {
        tx.update(counterRef, {'studentCounter': newTotal});
      } else {
        tx.set(counterRef, {'studentCounter': newTotal, 'receiptCounter': 0});
      }
    });

    final year = DateTime.now().year;
    return List.generate(count, (i) {
      final num = startNum + i;
      return '$prefix$year${num.toString().padLeft(4, '0')}';
    });
  }
}
