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
    final counterRef = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('counters');
    
    int nextNum = 1;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['studentCounter'] as int?) ?? 0;
      nextNum = current + 1;
      if (snap.exists) {
        tx.update(counterRef, {'studentCounter': nextNum});
      } else {
        tx.set(counterRef, {'studentCounter': nextNum, 'receiptCounter': 0});
      }
    });
    
    final year = DateTime.now().year;
    return '$prefix$year${nextNum.toString().padLeft(4, '0')}';
  }
}
