import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/services/telegram_service.dart';

class OwnerDigestSummary {
  final String title;
  final String htmlContent;
  final String plainText;
  final Map<String, dynamic> stats;

  const OwnerDigestSummary({
    required this.title,
    required this.htmlContent,
    required this.plainText,
    required this.stats,
  });
}

/// Owner Digest Service: Automates Morning (8:00 AM) Operational Briefings
/// and Nightly (11:00 PM) Financial Settlement reports via Telegram & FCM Push.
class OwnerDigestService {
  final FirebaseFirestore _firestore;

  OwnerDigestService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Compiles the 8:00 AM Morning Briefing:
  /// - Real-time occupancy % and total occupied vs capacity
  /// - Memberships expiring today (T-0) and within 3 days (T-3)
  /// - Live waiting list queue count
  /// - Pending student requests (admissions, renewals, seat changes)
  Future<OwnerDigestSummary> generateMorningBriefing(String libraryId) async {
    final now = DateTime.now();
    final todayStr = DateFormat('dd MMM yyyy').format(now);
    final libRef = _firestore.collection(FirestorePaths.libraries).doc(libraryId);

    // 1. Library Name & Meta
    final libDoc = await libRef.get();
    final libName = libDoc.data()?['name'] as String? ?? 'The Cozy Corner Study Centre';

    // 2. Count live seats across sections
    int totalSeats = 0;
    int occupiedSeats = 0;
    try {
      final secSnap = await libRef.collection(FirestorePaths.sections).get();
      for (final sec in secSnap.docs) {
        final seatsSnap = await sec.reference.collection(FirestorePaths.seats).get();
        for (final seatDoc in seatsSnap.docs) {
          totalSeats++;
          final sData = seatDoc.data();
          if (sData['status'] == 'occupied') {
            occupiedSeats++;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Seat count error in digest: $e');
    }

    final occPercent = totalSeats > 0 ? ((occupiedSeats / totalSeats) * 100).round() : 0;
    final availableSeats = totalSeats - occupiedSeats;

    // 3. Expiries today and next 3 days
    final todayMid = DateTime(now.year, now.month, now.day);
    final expiringTodayList = <String>[];
    int expiringIn3DaysCount = 0;

    try {
      final studentsSnap = await libRef
          .collection(FirestorePaths.students)
          .where('membershipStatus', whereIn: ['active', 'grace'])
          .get();

      for (final sDoc in studentsSnap.docs) {
        final s = sDoc.data();
        final rawEnd = s['planEndDate'] ?? s['validTo'];
        if (rawEnd == null) continue;

        DateTime? planEnd;
        if (rawEnd is Timestamp) {
          planEnd = rawEnd.toDate();
        } else if (rawEnd is String) {
          planEnd = DateTime.tryParse(rawEnd);
        }

        if (planEnd == null) continue;

        final planEndMid = DateTime(planEnd.year, planEnd.month, planEnd.day);
        final diffDays = planEndMid.difference(todayMid).inDays;
        final name = s['name'] as String? ?? 'Student';
        final seat = s['seatLabel'] ?? s['seatId'] ?? 'Desk';

        if (diffDays == 0) {
          expiringTodayList.add('$name (Seat #$seat)');
        } else if (diffDays > 0 && diffDays <= 3) {
          expiringIn3DaysCount++;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Student expiries fetch error in digest: $e');
    }

    // 4. Waiting list count
    int waitingCount = 0;
    try {
      final waitSnap = await libRef.collection(FirestorePaths.waitingList).get();
      waitingCount = waitSnap.docs.length;
    } catch (_) {}

    // 5. Pending requests count
    int pendingRequests = 0;
    try {
      final reqSnap = await libRef
          .collection(FirestorePaths.requests)
          .where('status', isEqualTo: 'pending')
          .get();
      pendingRequests = reqSnap.docs.length;
    } catch (_) {}

    final title = '🌅 8:00 AM Morning Briefing — $todayStr';

    final html = StringBuffer()
      ..writeln('🏛️ <b>$libName</b>')
      ..writeln('🌅 <b>MORNING OPERATIONAL BRIEFING</b>')
      ..writeln('📅 <i>$todayStr • 08:00 AM IST</i>\n')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('📊 <b>LIVE DESK OCCUPANCY</b>')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('• Occupancy: <b>$occPercent%</b> ($occupiedSeats / $totalSeats seats)')
      ..writeln('• Available Desks: <b>$availableSeats</b>\n')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('⏳ <b>MEMBERSHIP RENEWALS</b>')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━');

    if (expiringTodayList.isNotEmpty) {
      html.writeln('⚠️ <b>Expiring Today (${expiringTodayList.length}):</b>');
      for (final s in expiringTodayList) {
        html.writeln('  • $s');
      }
    } else {
      html.writeln('✅ <i>Zero memberships expiring today.</i>');
    }

    if (expiringIn3DaysCount > 0) {
      html.writeln('📅 <b>Upcoming (Next 3 Days):</b> $expiringIn3DaysCount renewals due');
    }

    html
      ..writeln('\n━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('📋 <b>QUEUE & REQUESTS</b>')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('• Waiting List Queue: <b>$waitingCount aspirant(s)</b>')
      ..writeln('• Pending Student Requests: <b>$pendingRequests</b>\n')
      ..writeln('<i>Have a productive day running the center! 🚀</i>');

    final plain = html.toString().replaceAll(RegExp(r'<[^>]*>'), '');

    return OwnerDigestSummary(
      title: title,
      htmlContent: html.toString(),
      plainText: plain,
      stats: {
        'occPercent': occPercent,
        'occupiedSeats': occupiedSeats,
        'totalSeats': totalSeats,
        'expiringTodayCount': expiringTodayList.length,
        'expiringIn3DaysCount': expiringIn3DaysCount,
        'waitingCount': waitingCount,
        'pendingRequests': pendingRequests,
      },
    );
  }

  /// Compiles the 11:00 PM Nightly Financial Settlement:
  /// - Total revenue collected today
  /// - Breakdown: UPI / QR collections vs Cash at Reception desk
  /// - Count of official receipts issued
  /// - New student admissions registered today
  Future<OwnerDigestSummary> generateNightlySettlement(String libraryId) async {
    final now = DateTime.now();
    final todayStr = DateFormat('dd MMM yyyy').format(now);
    final todayStart = DateTime(now.year, now.month, now.day);
    final libRef = _firestore.collection(FirestorePaths.libraries).doc(libraryId);

    // 1. Library Name
    final libDoc = await libRef.get();
    final libName = libDoc.data()?['name'] as String? ?? 'The Cozy Corner Study Centre';

    // 2. Query today's payments
    double totalRevenue = 0.0;
    double upiRevenue = 0.0;
    double cashRevenue = 0.0;
    int paymentCount = 0;

    try {
      final paymentsSnap = await libRef
          .collection(FirestorePaths.payments)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      for (final pDoc in paymentsSnap.docs) {
        final p = pDoc.data();
        if (p['status'] == 'refunded') continue;

        final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final method = (p['method'] as String? ?? '').toLowerCase();

        totalRevenue += amt;
        paymentCount++;

        if (method.contains('upi') || method.contains('qr') || method.contains('online') || method.contains('gpay')) {
          upiRevenue += amt;
        } else {
          cashRevenue += amt;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Payments fetch error in nightly digest: $e');
    }

    // 3. Count official receipts issued today
    int receiptsCount = 0;
    try {
      final rSnap = await libRef
          .collection(FirestorePaths.receipts)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();
      receiptsCount = rSnap.docs.length;
    } catch (_) {}

    // 4. Count new admissions today
    int newAdmissions = 0;
    try {
      final sSnap = await libRef
          .collection(FirestorePaths.students)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();
      newAdmissions = sSnap.docs.length;
    } catch (_) {}

    final title = '🌙 11:00 PM Nightly Settlement — $todayStr';

    final html = StringBuffer()
      ..writeln('🏛️ <b>$libName</b>')
      ..writeln('🌙 <b>END-OF-DAY FINANCIAL SETTLEMENT</b>')
      ..writeln('📅 <i>$todayStr • 11:00 PM IST</i>\n')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('💰 <b>TOTAL DAILY COLLECTION</b>')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('💵 <b>Total Revenue: ₹${totalRevenue.toStringAsFixed(0)}</b> ($paymentCount transactions)\n')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('💳 <b>PAYMENT MODE BREAKDOWN</b>')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('• UPI / Online / QR: <b>₹${upiRevenue.toStringAsFixed(0)}</b>')
      ..writeln('• Cash at Reception: <b>₹${cashRevenue.toStringAsFixed(0)}</b>\n')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('🧾 <b>ACTIVITY & ADMISSIONS</b>')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('• Official Receipts Generated: <b>$receiptsCount</b>')
      ..writeln('• New Students Admitted: <b>$newAdmissions</b>\n')
      ..writeln('<i>All desk records synchronized for today. Good night! 😴✨</i>');

    final plain = html.toString().replaceAll(RegExp(r'<[^>]*>'), '');

    return OwnerDigestSummary(
      title: title,
      htmlContent: html.toString(),
      plainText: plain,
      stats: {
        'totalRevenue': totalRevenue,
        'upiRevenue': upiRevenue,
        'cashRevenue': cashRevenue,
        'receiptsCount': receiptsCount,
        'newAdmissions': newAdmissions,
      },
    );
  }

  /// Dispatches the Morning Briefing to Telegram Bot and Admin Notifications
  Future<bool> sendMorningBriefing({
    required String libraryId,
    required TelegramService telegramService,
  }) async {
    try {
      final summary = await generateMorningBriefing(libraryId);

      // In-app alert
      await AppNotificationService.sendNotification(
        libraryId: libraryId,
        title: summary.title,
        body: summary.plainText.substring(0, summary.plainText.length > 250 ? 250 : summary.plainText.length),
        type: 'digest',
        targetRole: 'admin',
        actionRoute: '/admin/dashboard',
      );

      // Fetch telegram credentials
      final commDoc = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection('settings')
          .doc('communications')
          .get();

      final data = commDoc.data() ?? {};
      final channels = (data['channels'] as Map<String, dynamic>?) ?? {};
      final botToken = channels['telegramBotToken'] as String? ?? '';
      final chatId = channels['telegramChatId'] as String? ?? '';

      if (botToken.isNotEmpty && chatId.isNotEmpty) {
        return await telegramService.sendMessage(
          botToken: botToken,
          chatId: chatId,
          message: summary.htmlContent,
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending morning briefing: $e');
      return false;
    }
  }

  /// Dispatches the Nightly Financial Settlement to Telegram Bot and Admin Notifications
  Future<bool> sendNightlySettlement({
    required String libraryId,
    required TelegramService telegramService,
  }) async {
    try {
      final summary = await generateNightlySettlement(libraryId);

      // In-app alert
      await AppNotificationService.sendNotification(
        libraryId: libraryId,
        title: summary.title,
        body: summary.plainText.substring(0, summary.plainText.length > 250 ? 250 : summary.plainText.length),
        type: 'digest',
        targetRole: 'admin',
        actionRoute: '/admin/revenue',
      );

      // Fetch telegram credentials
      final commDoc = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection('settings')
          .doc('communications')
          .get();

      final data = commDoc.data() ?? {};
      final channels = (data['channels'] as Map<String, dynamic>?) ?? {};
      final botToken = channels['telegramBotToken'] as String? ?? '';
      final chatId = channels['telegramChatId'] as String? ?? '';

      if (botToken.isNotEmpty && chatId.isNotEmpty) {
        return await telegramService.sendMessage(
          botToken: botToken,
          chatId: chatId,
          message: summary.htmlContent,
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending nightly settlement: $e');
      return false;
    }
  }
}
