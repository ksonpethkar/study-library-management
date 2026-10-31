import 'package:study_library/models/plan_model.dart';

/// Data class representing the result of a smart calendar-month-aligned plan calculation
class SmartPlanCalculation {
  final PlanModel plan;
  final DateTime startDate;
  final DateTime endDate;
  final int daysRemaining;
  final int totalCycleDays;
  final double dailyRate;
  final double fullPrice;
  final double proratedPrice;
  final bool isProrated;
  final String cycleLabel;

  const SmartPlanCalculation({
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.daysRemaining,
    required this.totalCycleDays,
    required this.dailyRate,
    required this.fullPrice,
    required this.proratedPrice,
    required this.isProrated,
    required this.cycleLabel,
  });

  /// Formatted daily rate string e.g. "₹25.0/day"
  String get formattedDailyRate => '₹${dailyRate.toStringAsFixed(1)}/day';

  /// Formatted prorated price string e.g. "₹1,850"
  String get formattedProratedPrice => '₹${proratedPrice.toStringAsFixed(0)}';

  /// Formatted full price string e.g. "₹2,300"
  String get formattedFullPrice => '₹${fullPrice.toStringAsFixed(0)}';

  /// Convenient alias for endDate
  DateTime get effectiveExpiry => endDate;
}

/// Data class representing the result of an early exit settlement and refund calculation
class ExitSettlementCalculation {
  final DateTime startDate;
  final DateTime originalEndDate;
  final DateTime exitDate;
  final int totalCycleDays;
  final int usedDays;
  final int unusedDays;
  final double dailyRate;
  final double totalPaid;
  final double fairUsageFee;
  final double grossRefund;
  final double processingFee;
  final double netRefund;
  final String explanation;

  const ExitSettlementCalculation({
    required this.startDate,
    required this.originalEndDate,
    required this.exitDate,
    required this.totalCycleDays,
    required this.usedDays,
    required this.unusedDays,
    required this.dailyRate,
    required this.totalPaid,
    required this.fairUsageFee,
    required this.grossRefund,
    required this.processingFee,
    required this.netRefund,
    required this.explanation,
  });

  String get formattedGrossRefund => '₹${grossRefund.toStringAsFixed(0)}';
  String get formattedNetRefund => '₹${netRefund.toStringAsFixed(0)}';
  String get formattedFairUsage => '₹${fairUsageFee.toStringAsFixed(0)}';
}

/// Data class representing the result of a plan upgrade / downgrade mid-cycle settlement
class PlanChangeSettlement {
  final PlanModel currentPlan;
  final PlanModel targetPlan;
  final DateTime changeDate;
  final DateTime currentStartDate;
  final DateTime currentEndDate;
  final int totalCurrentDays;
  final int usedDays;
  final int remainingDays;
  final double currentDailyRate;
  final double unusedCredit;
  final double newPlanProratedFee;
  final double netDifference; // Positive = student pays difference; Negative = refund/credit to student
  final bool isUpgrade;
  final DateTime newEndDate;
  final String explanation;

  const PlanChangeSettlement({
    required this.currentPlan,
    required this.targetPlan,
    required this.changeDate,
    required this.currentStartDate,
    required this.currentEndDate,
    required this.totalCurrentDays,
    required this.usedDays,
    required this.remainingDays,
    required this.currentDailyRate,
    required this.unusedCredit,
    required this.newPlanProratedFee,
    required this.netDifference,
    required this.isUpgrade,
    required this.newEndDate,
    required this.explanation,
  });

  double get payableByStudent => netDifference > 0 ? netDifference : 0.0;
  double get refundableToStudent => netDifference < 0 ? (-netDifference) : 0.0;
}

/// Service that computes fair prorated billing for plans aligned with calendar month ends
class PlanCalculatorService {
  /// Intelligently finds the monthly plan from catalog/active plans.
  /// Matches DurationUnit.months == 1, DurationUnit.days between 28 and 31 (e.g. 30 days),
  /// or any plan with "month" in its name.
  static PlanModel? findMonthlyPlan(Iterable<PlanModel> plans) {
    if (plans.isEmpty) return null;
    final m1 = plans.where((p) => p.durationUnit == DurationUnit.months && p.duration == 1).firstOrNull;
    if (m1 != null) return m1;
    final d30 = plans.where((p) => p.durationUnit == DurationUnit.days && p.duration >= 28 && p.duration <= 31).firstOrNull;
    if (d30 != null) return d30;
    final nameMatch = plans.where((p) => p.name.toLowerCase().contains('month')).firstOrNull;
    if (nameMatch != null) return nameMatch;
    return plans.firstOrNull;
  }

  /// Returns the base monthly price from plans catalog, defaulting to 700.0 if not yet configured.
  static double getBaseMonthlyPrice(Iterable<PlanModel> plans) {
    final m = findMonthlyPlan(plans);
    return m?.price ?? 700.0;
  }

  /// Computes end date from start date and plan duration parameters.
  /// Strictly aligns to the end of the calendar month (e.g. Oct 31 23:59:59).
  static DateTime calculatePlanEndDate(DateTime startDate, int duration, DurationUnit unit) {
    // Normalize startDate to start of day
    final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
    if (unit == DurationUnit.months) {
      if (cleanStart.day == 1) {
        return DateTime(cleanStart.year, cleanStart.month + duration, 0, 23, 59, 59);
      } else {
        // Ends on (start day - 1) of target month e.g. 23 Nov -> 22 Dec
        final targetMonth = cleanStart.month + duration;
        final targetYear = cleanStart.year + (targetMonth - 1) ~/ 12;
        final normalizedMonth = ((targetMonth - 1) % 12) + 1;
        final daysInTargetMonth = DateTime(targetYear, normalizedMonth + 1, 0).day;
        final targetDay = (cleanStart.day - 1).clamp(1, daysInTargetMonth);
        return DateTime(targetYear, normalizedMonth, targetDay, 23, 59, 59);
      }
    } else if (unit == DurationUnit.weeks) {
      return cleanStart.add(Duration(days: duration * 7)).subtract(const Duration(seconds: 1));
    } else {
      // Days-based plan: add exact days from the start date
      final effectiveDays = duration > 0 ? duration : 30;
      return cleanStart
          .add(Duration(days: effectiveDays))
          .subtract(const Duration(seconds: 1));
    }
  }

  /// Computes the effective daily rate for any plan
  static double getDailyRate(PlanModel plan) {
    if (plan.price <= 0) return 0.0;
    final standardDays = getStandardCycleDays(plan);
    if (standardDays <= 0) return 0.0;
    return plan.price / standardDays;
  }

  /// Returns the standard number of days for the plan duration
  static int getStandardCycleDays(PlanModel plan) {
    final duration = plan.duration > 0 ? plan.duration : 1;
    switch (plan.durationUnit) {
      case DurationUnit.days:
        return 30; // standard calendar month basis
      case DurationUnit.weeks:
        return duration * 7;
      case DurationUnit.months:
        if (duration == 1) return 30;
        if (duration == 3) return 90; // Standard Quarter
        if (duration == 6) return 180; // Standard Half-Year
        if (duration == 12) return 365; // Standard Annual
        return duration * 30;
    }
  }

  /// Calculates smart calendar-month-end aligned plan details.
  /// Strictly aligns to the current calendar month end (e.g. Oct 31 23:59:59).
  /// Mid-month joiners are automatically and fairly prorated for remaining days.
  static SmartPlanCalculation calculateSmartPlan({
    required PlanModel plan,
    DateTime? fromDate,
  }) {
    final start = fromDate ?? DateTime.now();
    final startDay = DateTime(start.year, start.month, start.day);
    final isDays = plan.durationUnit == DurationUnit.days;
    final int duration = isDays
        ? ((plan.duration / 30).round().clamp(1, 12))
        : (plan.duration > 0 ? plan.duration : 1);

    DateTime cycleStart;
    DateTime cycleEnd;
    String cycleLabel;
    int totalCycleDays;
    int daysRemaining;
    bool isProrated = false;

    if (plan.durationUnit == DurationUnit.months || isDays) {
      // Calendar month alignment:
      // Current month counts as Month 1.
      // e.g. 1 month / 30 days from Oct -> 31 Oct 23:59:59
      // e.g. 3 months (Quarterly) from Oct -> 31 Dec 23:59:59 (Oct, Nov, Dec)
      // e.g. 6 months (Half-Yearly) from Oct -> 31 Mar 23:59:59
      // e.g. 12 months (Annual) from Oct -> 30 Sep 23:59:59
      // Day 0 of (startDay.month + duration) is exactly the last day of month (startDay.month + duration - 1)
      cycleStart = DateTime(startDay.year, startDay.month, 1);
      cycleEnd = DateTime(startDay.year, startDay.month + duration, 0, 23, 59, 59);

      if (duration == 1) {
        cycleLabel = 'Current Month (ends ${_monthName(cycleEnd.month)} ${cycleEnd.day})';
      } else if (duration == 3) {
        cycleLabel = 'Quarterly (ends ${_monthName(cycleEnd.month)} ${cycleEnd.day})';
      } else if (duration == 6) {
        cycleLabel = 'Half-Yearly (ends ${_monthName(cycleEnd.month)} ${cycleEnd.day})';
      } else if (duration == 12) {
        cycleLabel = 'Annual (ends ${_monthName(cycleEnd.month)} ${cycleEnd.day})';
      } else {
        cycleLabel = '${duration}M Cycle (ends ${_monthName(cycleEnd.month)} ${cycleEnd.day})';
      }

      totalCycleDays = cycleEnd.difference(cycleStart).inDays + 1;
      daysRemaining = cycleEnd.difference(startDay).inDays + 1;

      // If student joins mid-cycle (after the 1st), auto-prorate fairly for remaining days
      isProrated = startDay.day > 1 && daysRemaining < totalCycleDays && totalCycleDays > 0;
    } else if (plan.durationUnit == DurationUnit.weeks) {
      cycleStart = startDay;
      cycleEnd = startDay.add(Duration(days: duration * 7)).subtract(const Duration(seconds: 1));
      cycleLabel = '$duration Weeks';
      totalCycleDays = duration * 7;
      daysRemaining = totalCycleDays;
      isProrated = false;
    } else {
      // Fallback: Snap to calendar month end
      cycleStart = DateTime(startDay.year, startDay.month, 1);
      cycleEnd = DateTime(startDay.year, startDay.month + 1, 0, 23, 59, 59);
      cycleLabel = 'Current Month';
      totalCycleDays = cycleEnd.difference(cycleStart).inDays + 1;
      daysRemaining = cycleEnd.difference(startDay).inDays + 1;
      isProrated = startDay.day > 1 && daysRemaining < totalCycleDays && totalCycleDays > 0;
    }

    // Standard daily rate from plan definition (matches Membership Plans screen 1:1)
    final standardDailyRate = getDailyRate(plan);

    // Exact cycle daily rate for proportional mid-cycle proration
    final cycleDailyRate = (totalCycleDays > 0 && plan.price > 0)
        ? (plan.price / totalCycleDays)
        : standardDailyRate;

    double proratedPrice = plan.price;
    if (isProrated) {
      final rawFee = daysRemaining * cycleDailyRate;
      // Round to nearest 50 for clean cash/UPI handling (e.g. 65d x ₹21.74 = ₹1,413 -> ₹1,400)
      proratedPrice = ((rawFee / 50).round() * 50.0).clamp(50.0, plan.price);
    }

    return SmartPlanCalculation(
      plan: plan,
      startDate: startDay,
      endDate: cycleEnd,
      daysRemaining: daysRemaining > 0 ? daysRemaining : 1,
      totalCycleDays: totalCycleDays,
      dailyRate: standardDailyRate,
      fullPrice: plan.price,
      proratedPrice: proratedPrice,
      isProrated: isProrated,
      cycleLabel: cycleLabel,
    );
  }

  /// Calculates pricing for sub-1-month custom durations based on the Monthly Plan price
  static double calculateSubMonthPrice({
    required int days,
    required double monthlyPrice,
  }) {
    if (days <= 0 || monthlyPrice <= 0) return 0.0;
    final dailyRate = monthlyPrice / 30.0;
    final raw = days * dailyRate;
    // Round to nearest 5 for clean cash handling
    return (raw / 5).round() * 5.0;
  }

  /// Computes fair pro-rata exit settlement, unused days, fair usage fee, and refund amount
  static ExitSettlementCalculation calculateExitSettlement({
    required DateTime startDate,
    required DateTime originalEndDate,
    required DateTime exitDate,
    required double totalPaid,
    required PlanModel plan,
    double processingFee = 0.0,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final origEnd = DateTime(originalEndDate.year, originalEndDate.month, originalEndDate.day);
    final exit = DateTime(exitDate.year, exitDate.month, exitDate.day);

    final totalDays = origEnd.difference(start).inDays + 1;
    final used = (exit.difference(start).inDays + 1).clamp(0, totalDays);
    final unused = (totalDays - used).clamp(0, totalDays);

    final dailyRate = totalDays > 0 ? (plan.price / totalDays) : getDailyRate(plan);

    double fairUsageFee = 0.0;
    if (used >= totalDays) {
      fairUsageFee = totalPaid;
    } else if (used > 0) {
      final rawUsage = used * dailyRate;
      // Round to nearest 10 for clean handling
      fairUsageFee = ((rawUsage / 10).round() * 10.0).clamp(0.0, totalPaid);
    }

    final grossRefund = (totalPaid - fairUsageFee).clamp(0.0, double.infinity);
    final netRefund = (grossRefund - processingFee).clamp(0.0, double.infinity);

    final explanation = used >= totalDays
        ? 'Full term of $totalDays days completed. No refund applicable.'
        : 'Used $used of $totalDays days ($unused days unused). Fair usage: ₹${fairUsageFee.toStringAsFixed(0)} out of ₹${totalPaid.toStringAsFixed(0)} paid.';

    return ExitSettlementCalculation(
      startDate: start,
      originalEndDate: origEnd,
      exitDate: exit,
      totalCycleDays: totalDays,
      usedDays: used,
      unusedDays: unused,
      dailyRate: dailyRate,
      totalPaid: totalPaid,
      fairUsageFee: fairUsageFee,
      grossRefund: grossRefund,
      processingFee: processingFee,
      netRefund: netRefund,
      explanation: explanation,
    );
  }

  /// Computes fair credit adjustment when upgrading or downgrading between plans mid-cycle
  static PlanChangeSettlement calculatePlanChangeSettlement({
    required PlanModel currentPlan,
    required PlanModel targetPlan,
    required DateTime currentStartDate,
    required DateTime currentEndDate,
    DateTime? changeDate,
    required double totalPaidForCurrent,
  }) {
    final now = changeDate ?? DateTime.now();
    final change = DateTime(now.year, now.month, now.day);
    final start = DateTime(currentStartDate.year, currentStartDate.month, currentStartDate.day);
    final end = DateTime(currentEndDate.year, currentEndDate.month, currentEndDate.day);

    final totalDays = end.difference(start).inDays + 1;
    final used = (change.difference(start).inDays).clamp(0, totalDays);
    final remaining = (totalDays - used).clamp(0, totalDays);

    final currentDailyRate = totalDays > 0 ? (currentPlan.price / totalDays) : getDailyRate(currentPlan);
    final rawCredit = remaining * currentDailyRate;
    final unusedCredit = ((rawCredit / 10).round() * 10.0).clamp(0.0, totalPaidForCurrent);

    // Target plan calculation for remaining days
    final targetSmart = calculateSmartPlan(plan: targetPlan, fromDate: change);
    final targetDailyRate = getDailyRate(targetPlan);

    final rawNewFee = remaining * targetDailyRate;
    final newPlanProratedFee = ((rawNewFee / 10).round() * 10.0).clamp(0.0, targetPlan.price);

    final netDifference = newPlanProratedFee - unusedCredit;
    final isUpgrade = netDifference >= 0;

    final explanation = isUpgrade
        ? 'Upgrade to "${targetPlan.displayName}": Unused credit from current plan is ₹${unusedCredit.toStringAsFixed(0)} ($remaining days). New plan fee for $remaining days is ₹${newPlanProratedFee.toStringAsFixed(0)}. Net payable: ₹${netDifference.toStringAsFixed(0)}.'
        : 'Downgrade to "${targetPlan.displayName}": Unused credit from current plan is ₹${unusedCredit.toStringAsFixed(0)} ($remaining days). New plan fee is ₹${newPlanProratedFee.toStringAsFixed(0)}. Credit/Refund due: ₹${(-netDifference).toStringAsFixed(0)}.';

    return PlanChangeSettlement(
      currentPlan: currentPlan,
      targetPlan: targetPlan,
      changeDate: change,
      currentStartDate: start,
      currentEndDate: end,
      totalCurrentDays: totalDays,
      usedDays: used,
      remainingDays: remaining,
      currentDailyRate: currentDailyRate,
      unusedCredit: unusedCredit,
      newPlanProratedFee: newPlanProratedFee,
      netDifference: netDifference,
      isUpgrade: isUpgrade,
      newEndDate: targetSmart.endDate,
      explanation: explanation,
    );
  }

  static String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }
}
