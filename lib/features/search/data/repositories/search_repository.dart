import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:study_library/core/utils/seat_helper.dart';

enum SearchResultType { student, seat, payment, plan, announcement }

class SearchResultItem {
  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? route;

  const SearchResultItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.route,
  });
}

class SearchRepository {
  final FirebaseFirestore _firestore;

  SearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<SearchResultItem>> searchAll(String libraryId, String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2 || libraryId.isEmpty) return [];

    final results = <SearchResultItem>[];

    try {
      // 1. Search Students (name, phone, email, membershipNumber, seatId)
      final studentsSnap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .limit(100)
          .get();

      for (final doc in studentsSnap.docs) {
        final d = doc.data();
        final name = (d['name'] ?? '').toString().toLowerCase();
        final phone = (d['phone'] ?? '').toString().toLowerCase();
        final email = (d['email'] ?? '').toString().toLowerCase();
        final memNum = (d['membershipNumber'] ?? '').toString().toLowerCase();
        final seatId = (d['seatId'] ?? '').toString().toLowerCase();
        final deskStr = SeatHelper.formatSeatNumberOnly(seatId: seatId);

        if (name.contains(q) ||
            phone.contains(q) ||
            email.contains(q) ||
            memNum.contains(q) ||
            deskStr == q ||
            '#$deskStr' == q ||
            'desk $deskStr'.contains(q)) {
          final seatFormatted = SeatHelper.formatDeskLabel(seatId: d['seatId'] as String?);
          results.add(SearchResultItem(
            type: SearchResultType.student,
            id: doc.id,
            title: d['name']?.toString() ?? 'Student',
            subtitle: '${d['phone'] ?? ''} • $seatFormatted',
            icon: Icons.person_rounded,
            color: const Color(0xFF2563EB),
            route: '/admin/students',
          ));
        }
      }

      // 2. Search Plans
      final plansSnap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('plans')
          .get();

      for (final doc in plansSnap.docs) {
        final d = doc.data();
        final name = (d['name'] ?? '').toString().toLowerCase();
        if (name.contains(q)) {
          results.add(SearchResultItem(
            type: SearchResultType.plan,
            id: doc.id,
            title: d['name']?.toString() ?? 'Plan',
            subtitle: '₹${d['price'] ?? 0} • ${d['duration'] ?? d['durationDays'] ?? 0} ${d['durationUnit'] ?? 'days'}',
            icon: Icons.card_membership_rounded,
            color: const Color(0xFF059669),
            route: '/admin/plans',
          ));
        }
      }

      // 3. Search Announcements
      final announcementsSnap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('announcements')
          .limit(30)
          .get();

      for (final doc in announcementsSnap.docs) {
        final d = doc.data();
        final title = (d['title'] ?? '').toString().toLowerCase();
        final message = (d['message'] ?? '').toString().toLowerCase();
        if (title.contains(q) || message.contains(q)) {
          results.add(SearchResultItem(
            type: SearchResultType.announcement,
            id: doc.id,
            title: d['title']?.toString() ?? 'Announcement',
            subtitle: d['message']?.toString() ?? '',
            icon: Icons.campaign_rounded,
            color: const Color(0xFF7C3AED),
            route: '/admin/announcements',
          ));
        }
      }

      // 4. Search Payments / Receipts (receiptId, transactionId, studentName)
      final paymentsSnap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('payments')
          .limit(50)
          .get();

      for (final doc in paymentsSnap.docs) {
        final d = doc.data();
        final receiptId = (d['receiptId'] ?? d['receiptNumber'] ?? '').toString().toLowerCase();
        final txId = (d['transactionId'] ?? d['referenceNumber'] ?? '').toString().toLowerCase();
        final sName = (d['studentName'] ?? '').toString().toLowerCase();

        if (receiptId.contains(q) || txId.contains(q) || sName.contains(q)) {
          results.add(SearchResultItem(
            type: SearchResultType.payment,
            id: doc.id,
            title: 'Receipt #${d['receiptId'] ?? d['receiptNumber'] ?? doc.id.substring(0, 6)}',
            subtitle: '${d['studentName'] ?? ''} • ₹${d['amount'] ?? 0} (${d['method'] ?? d['paymentMethod'] ?? 'Cash'})',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFD97706),
            route: '/admin/payments',
          ));
        }
      }
    } catch (_) {}

    return results;
  }
}
