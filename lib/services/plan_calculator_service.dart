import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/student_model.dart';

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

  // Bridge Bundle Fields (Available when joining on or after Day 20)
  final bool hasBridgeOption;
  final double? bridgePrice;
  final DateTime? bridgeEndDate;
  final String? bridgeCycleLabel;

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
    this.hasBridgeOption = false,
    this.bridgePrice,
    this.bridgeEndDate,
    this.bridgeCycleLabel,
  });

  /// Formatted daily rate string e.g. "₹25.0/day"
  String get formattedDailyRate => '₹${dailyRate.toStringAsFixed(1)}/day';

  /// Formatted prorated price string e.g. "₹1,850"
  String get formattedProratedPrice => '₹${proratedPrice.toStringAsFixed(0)}';

  /// Formatted full price string e.g. "₹2,300"
  String get formattedFullPrice => '₹${fullPrice.toStringAsFixed(0)}';

  /// Formatted bridge bundle price string e.g. "₹2,950"
  String? get formattedBridgePrice => bridgePrice != null ? '₹${bridgePrice!.toStringAsFixed(0)}' : null;

  /// Convenient alias for endDate
  DateTime get effectiveExpiry => endDate;
}

enum RenewalType {
  advance,          // Renewing before expiry (extends from planEndDate + 1 day)
  backdatedGrace,   // Renewing during grace period (< 10 days since expiry, backdated to 1st of month)
  gapRenewal,       // Renewing after 10+ days gap (starts fresh from today with pro-rata / bridge options)
  fresh,            // Fresh admission or inactive student
}

/// Data class representing the result of a student membership renewal calculation
class RenewalCalculation {
  final RenewalType type;
  final DateTime startDate;
  final DateTime endDate;
  final double price;
  final bool isProrated;
  final String explanation;
  final SmartPlanCalculation smartCalc;

  const RenewalCalculation({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.isProrated,
    required this.explanation,
    required this.smartCalc,
  });

  String get formattedPrice => '₹${price.toStringAsFixed(0)}';
}

/// Data class representing the result of a membership freeze / study vacation calculation (10+ days)
class FreezeCalculation {
  final DateTime originalEndDate;
  final DateTime freezeStartDate;
  final DateTime freezeEndDate;
  final int freezeDays;
  final DateTime newEndDate;
  final bool isValid;
  final String message;

  const FreezeCalculation({
    required this.originalEndDate,
    required this.freezeStartDate,
    required this.freezeEndDate,
    required this.freezeDays,
    required this.newEndDate,
    required this.isValid,
    required this.message,
  });
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
  /// Joining on or after Day 20 activates the "Bridge Bundle" option (Remainder + Next Full Month).
  static SmartPlanCalculation calculateSmartPlan({
    required PlanModel plan,
    DateTime? fromDate,
    bool isBridgeBundle = false,
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

    // Check if Bridge Bundle option is available (Joining on or after 20th of the month)
    final bool hasBridgeOption = startDay.day >= 20 && (plan.durationUnit == DurationUnit.months || isDays);
    double? bridgePrice;
    DateTime? bridgeEndDate;
    String? bridgeCycleLabel;

    if (plan.durationUnit == DurationUnit.months || isDays) {
      // 1. Current Month Calculations
      final daysInCurrentMonth = DateTime(startDay.year, startDay.month + 1, 0).day;
      final daysRemainingInCurrentMonth = (daysInCurrentMonth - startDay.day + 1).clamp(1, daysInCurrentMonth);
      final currentMonthDailyRate = plan.price / daysInCurrentMonth;
      final rawCurrentMonthFee = daysRemainingInCurrentMonth * currentMonthDailyRate;
      final currentMonthProrated = startDay.day == 1
          ? plan.price
          : ((rawCurrentMonthFee / 10).round() * 10.0).clamp(50.0, plan.price);

      // 2. Next Month Calculations (for Bridge Bundle)
      if (hasBridgeOption) {
        final nextMonthStart = DateTime(startDay.year, startDay.month + 1, 1);
        bridgeEndDate = DateTime(nextMonthStart.year, nextMonthStart.month + duration, 0, 23, 59, 59);
        final rawBridgePrice = currentMonthProrated + plan.price;
        // Clean round to 10 for cash/UPI handling
        bridgePrice = ((rawBridgePrice / 10).round() * 10.0);
        bridgeCycleLabel = 'Bridge Pass: Rest of ${_monthName(startDay.month)} (${daysRemainingInCurrentMonth}d) + Full ${_monthName(nextMonthStart.month)}';
      }

      if (isBridgeBundle && hasBridgeOption && bridgeEndDate != null && bridgePrice != null) {
        cycleStart = startDay;
        cycleEnd = bridgeEndDate;
        cycleLabel = bridgeCycleLabel!;
        totalCycleDays = cycleEnd.difference(DateTime(startDay.year, startDay.month, 1)).inDays + 1;
        daysRemaining = cycleEnd.difference(startDay).inDays + 1;
        isProrated = true;
      } else {
        cycleStart = DateTime(startDay.year, startDay.month, 1);
        cycleEnd = DateTime(startDay.year, startDay.month + duration, 0, 23, 59, 59);
        totalCycleDays = cycleEnd.difference(cycleStart).inDays + 1;
        daysRemaining = cycleEnd.difference(startDay).inDays + 1;
        isProrated = startDay.day > 1 && daysRemaining < totalCycleDays && totalCycleDays > 0;

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
      }
    } else if (plan.durationUnit == DurationUnit.weeks) {
      cycleStart = startDay;
      cycleEnd = startDay.add(Duration(days: duration * 7)).subtract(const Duration(seconds: 1));
      cycleLabel = '$duration Weeks';
      totalCycleDays = duration * 7;
      daysRemaining = totalCycleDays;
      isProrated = false;
    } else {
      // Days-based fallback
      cycleStart = startDay;
      cycleEnd = startDay.add(Duration(days: plan.duration > 0 ? plan.duration : 1)).subtract(const Duration(seconds: 1));
      cycleLabel = '${plan.duration} Days';
      totalCycleDays = plan.duration > 0 ? plan.duration : 1;
      daysRemaining = totalCycleDays;
      isProrated = false;
    }

    final standardDailyRate = getDailyRate(plan);

    double finalProratedPrice = plan.price;
    if (isBridgeBundle && bridgePrice != null) {
      finalProratedPrice = bridgePrice;
    } else if (isProrated) {
      final daysInCurrentMonth = DateTime(startDay.year, startDay.month + 1, 0).day;
      final currentDailyRate = plan.price / daysInCurrentMonth;
      final rawFee = daysRemaining * currentDailyRate;
      finalProratedPrice = ((rawFee / 10).round() * 10.0).clamp(50.0, plan.price);
    }

    return SmartPlanCalculation(
      plan: plan,
      startDate: startDay,
      endDate: cycleEnd,
      daysRemaining: daysRemaining > 0 ? daysRemaining : 1,
      totalCycleDays: totalCycleDays,
      dailyRate: standardDailyRate,
      fullPrice: plan.price,
      proratedPrice: finalProratedPrice,
      isProrated: isProrated,
      cycleLabel: cycleLabel,
      hasBridgeOption: hasBridgeOption,
      bridgePrice: bridgePrice,
      bridgeEndDate: bridgeEndDate,
      bridgeCycleLabel: bridgeCycleLabel,
    );
  }

  /// Calculates renewal parameters honoring:
  /// - Advance Renewal (renewing before expiry: extends seamlessly from current planEndDate)
  /// - Backdated Grace Renewal (< 10 days since expiry: backdates to 1st of month to protect seats)
  /// - Gap Renewal (>= 10 days since expiry: student was on a break, starts fresh from today with pro-rata!)
  static RenewalCalculation calculateRenewal({
    required StudentModel student,
    required PlanModel plan,
    DateTime? fromDate,
    bool chooseBridgeBundle = false,
  }) {
    final now = fromDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentEnd = student.planEndDate;

    if (currentEnd != null) {
      final cleanCurrentEnd = DateTime(currentEnd.year, currentEnd.month, currentEnd.day);

      // 1. Advance Renewal: current membership has not expired yet
      if (cleanCurrentEnd.isAfter(today) || cleanCurrentEnd.isAtSameMomentAs(today)) {
        final nextStart = DateTime(cleanCurrentEnd.year, cleanCurrentEnd.month, cleanCurrentEnd.day + 1);
        final nextEnd = DateTime(nextStart.year, nextStart.month + plan.duration, 0, 23, 59, 59);
        final smartCalc = calculateSmartPlan(plan: plan, fromDate: nextStart);
        return RenewalCalculation(
          type: RenewalType.advance,
          startDate: nextStart,
          endDate: nextEnd,
          price: plan.price,
          isProrated: false,
          explanation: 'Advance Renewal: Continuous coverage starting ${_monthName(nextStart.month)} ${nextStart.day} until ${_monthName(nextEnd.month)} ${nextEnd.day}.',
          smartCalc: smartCalc,
        );
      }

      // 2. Expired: calculate the gap in days
      final daysSinceExpiry = today.difference(cleanCurrentEnd).inDays;

      // 3. Backdated Grace Renewal (< 10 days gap)
      // Student occupied the seat during grace period; backdate to 1st of current renewal month
      if (daysSinceExpiry < 10) {
        final backdatedStart = DateTime(cleanCurrentEnd.year, cleanCurrentEnd.month, cleanCurrentEnd.day + 1);
        final cycleEnd = DateTime(backdatedStart.year, backdatedStart.month + plan.duration, 0, 23, 59, 59);
        final smartCalc = calculateSmartPlan(plan: plan, fromDate: backdatedStart);
        return RenewalCalculation(
          type: RenewalType.backdatedGrace,
          startDate: backdatedStart,
          endDate: cycleEnd,
          price: plan.price,
          isProrated: false,
          explanation: 'Continuous Grace Renewal ($daysSinceExpiry days past expiry): Backdated to ${_monthName(backdatedStart.month)} ${backdatedStart.day} to retain your continuous seat registration.',
          smartCalc: smartCalc,
        );
      }

      // 4. Gap Renewal (>= 10 days gap):
      // Student was genuinely away for 10+ days! Starts fresh from TODAY with fair pro-rata or bridge pass!
      final smartCalc = calculateSmartPlan(
        plan: plan,
        fromDate: today,
        isBridgeBundle: chooseBridgeBundle,
      );
      return RenewalCalculation(
        type: RenewalType.gapRenewal,
        startDate: today,
        endDate: smartCalc.endDate,
        price: smartCalc.proratedPrice,
        isProrated: smartCalc.isProrated,
        explanation: 'Gap Renewal: Welcome back after a break of $daysSinceExpiry days! Starts fresh from today (${_monthName(today.month)} ${today.day}) with fair pro-rata pricing.',
        smartCalc: smartCalc,
      );
    }

    // 5. Fresh / Initial student calculation
    final smartCalc = calculateSmartPlan(
      plan: plan,
      fromDate: today,
      isBridgeBundle: chooseBridgeBundle,
    );
    return RenewalCalculation(
      type: RenewalType.fresh,
      startDate: today,
      endDate: smartCalc.endDate,
      price: smartCalc.proratedPrice,
      isProrated: smartCalc.isProrated,
      explanation: 'New Admission: Starts today (${_monthName(today.month)} ${today.day}) until ${_monthName(smartCalc.endDate.month)} ${smartCalc.endDate.day}.',
      smartCalc: smartCalc,
    );
  }

  /// Calculates study vacation / membership freeze validity extension (10 and 10+ days rule)
  static FreezeCalculation calculateMembershipFreeze({
    required StudentModel student,
    required DateTime freezeStartDate,
    required DateTime freezeEndDate,
  }) {
    final origEnd = student.planEndDate ?? DateTime.now();
    final cleanStart = DateTime(freezeStartDate.year, freezeStartDate.month, freezeStartDate.day);
    final cleanEnd = DateTime(freezeEndDate.year, freezeEndDate.month, freezeEndDate.day);

    final freezeDays = cleanEnd.difference(cleanStart).inDays + 1;

    if (freezeDays < 10) {
      return FreezeCalculation(
        originalEndDate: origEnd,
        freezeStartDate: cleanStart,
        freezeEndDate: cleanEnd,
        freezeDays: freezeDays,
        newEndDate: origEnd,
        isValid: false,
        message: 'Membership freeze is only permitted for 10 or more consecutive days ($freezeDays days selected).',
      );
    }

    final newEndDate = origEnd.add(Duration(days: freezeDays));
    return FreezeCalculation(
      originalEndDate: origEnd,
      freezeStartDate: cleanStart,
      freezeEndDate: cleanEnd,
      freezeDays: freezeDays,
      newEndDate: newEndDate,
      isValid: true,
      message: 'Study vacation approved for $freezeDays days. Validity extended from ${_monthName(origEnd.month)} ${origEnd.day} to ${_monthName(newEndDate.month)} ${newEndDate.day}.',
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
