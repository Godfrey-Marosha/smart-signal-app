// Street Signal prediction engine.
//
// Plain Dart, so it is easy to unit test and to port to C# for the .NET
// backend. Each model is simple enough to explain to judges in one sentence:
//  * Electricity run-out: recent daily use (weighted to the last week) vs units left.
//  * Budget: this month's spend projected to month end.
//  * Outage windows: how often each hour of the week had an outage over the last weeks.
//  * Outage duration: median and 80th percentile of past outages.
import 'dart:math' as math;

import '../core/enums.dart';
import '../core/format.dart';
import '../models/household.dart';
import '../models/records.dart';

const double defaultTariffRandsPerKwh = 3.40;

class ElectricityForecast {
  ElectricityForecast({
    required this.dailyKwh,
    required this.unitsLeft,
    required this.daysLeft,
    required this.runOut,
    required this.tariff,
    required this.suggestedTopupCents,
  });

  final double dailyKwh;
  final double unitsLeft;
  final double daysLeft;
  final DateTime runOut;

  /// Rands per kWh from recent purchases.
  final double tariff;

  /// About a week of use, rounded up to R10.
  final int suggestedTopupCents;
}

class BudgetForecast {
  BudgetForecast({required this.spentCents, required this.projectedCents, required this.budgetCents});
  final int spentCents;
  final int projectedCents;
  final int budgetCents;
  int get overCents => projectedCents - budgetCents;
  bool get isOver => budgetCents > 0 && projectedCents > budgetCents;
}

class OutageWindow {
  OutageWindow({required this.service, required this.start, required this.end, required this.probability, required this.weeksObserved});
  final Service service;
  final DateTime start;
  final DateTime end;
  final double probability;
  final int weeksObserved;
}

class DurationStats {
  DurationStats({required this.medianHours, required this.p80Hours, required this.sample});
  final double medianHours;
  final double p80Hours;
  final int sample;
}


class DailyUsage {
  DailyUsage(this.day, this.kwh);
  final DateTime day;
  final double kwh;
}

/// What Street Signal has done for this household.
class HouseholdImpact {
  HouseholdImpact({
    required this.sinceDays,
    required this.outagesWarned,
    required this.avgWarningHours,
    required this.forecastsChecked,
    required this.accuracy,
    required this.litresStored,
    required this.runOutsAvoided,
    required this.usageChange,
  });

  final int sinceDays;
  final int outagesWarned;
  final double? avgWarningHours;
  final int forecastsChecked;
  final double? accuracy;
  final int litresStored;
  final int runOutsAvoided;

  /// e.g. -0.18 = using 18% less electricity than the two weeks before.
  final double? usageChange;
}

/// What the area's reports add up to.
class AreaSummary {
  AreaSummary({
    required this.households,
    required this.reports,
    required this.outages,
    required this.weeks,
    required this.water,
    required this.power,
    required this.worstTime,
  });

  final int households;
  final int reports;
  final int outages;
  final int weeks;
  final DurationStats? water;
  final DurationStats? power;

  /// e.g. "Tue 18:00 · water"
  final String? worstTime;
}

class PredictionEngine {
  const PredictionEngine();

  // ---------------------------------------------------------------- electricity

  ElectricityForecast? electricity(List<Reading> readings, List<Topup> topups, DateTime now) {
    final units = readings.where((r) => r.kind == ReadingKind.elecUnits && !r.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    if (units.length < 2) return null;

    double boughtBetween(DateTime a, DateTime b) =>
        topups.where((t) => t.date.isAfter(a) && !t.date.isAfter(b)).fold(0.0, (s, t) => s + t.units);

    var weightedUse = 0.0;
    var weightedDays = 0.0;
    for (var i = 1; i < units.length; i++) {
      final a = units[i - 1];
      final b = units[i];
      final days = b.at.difference(a.at).inMinutes / (60 * 24);
      if (days < 0.25) continue;
      final used = a.value + boughtBetween(a.at, b.at) - b.value;
      if (used < 0) continue; // inconsistent reading, skip it
      final w = math.exp(-(now.difference(b.at).inHours / 24) / 7);
      weightedUse += w * used;
      weightedDays += w * days;
    }
    if (weightedDays <= 0) return null;
    final dailyKwh = weightedUse / weightedDays;

    final latest = units.last;
    final sinceLatestDays = now.difference(latest.at).inMinutes / (60 * 24);
    final unitsLeft = math.max(0.0, latest.value + boughtBetween(latest.at, now) - dailyKwh * sinceLatestDays);
    final daysLeft = dailyKwh > 0 ? unitsLeft / dailyKwh : 999.0;

    final recent = [...topups]..sort((a, b) => b.date.compareTo(a.date));
    final lastFive = recent.take(5).toList();
    final totalUnits = lastFive.fold(0.0, (s, t) => s + t.units);
    final totalRands = lastFive.fold(0.0, (s, t) => s + t.amountCents / 100);
    final tariff = totalUnits > 0 ? totalRands / totalUnits : defaultTariffRandsPerKwh;

    return ElectricityForecast(
      dailyKwh: dailyKwh,
      unitsLeft: unitsLeft,
      daysLeft: daysLeft,
      runOut: now.add(Duration(minutes: math.min((daysLeft * 24 * 60).round(), 365 * 24 * 60))),
      tariff: tariff,
      suggestedTopupCents: ((dailyKwh * 7 * tariff) / 10).ceil() * 10 * 100,
    );
  }

  BudgetForecast? electricityBudget(int budgetCents, List<Topup> topups, ElectricityForecast? f, DateTime now) {
    if (budgetCents <= 0) return null;
    final spent = topups
        .where((t) => t.date.year == now.year && t.date.month == now.month && !t.date.isAfter(now))
        .fold(0, (s, t) => s + t.amountCents);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = daysInMonth - now.day + (24 - now.hour) / 24;
    final int projected;
    if (f != null) {
      // Units on hand cover `daysLeft`; anything after that has to be bought.
      final extraDays = math.max(0.0, remainingDays - f.daysLeft);
      projected = spent + (extraDays * f.dailyKwh * f.tariff * 100).round();
    } else {
      projected = (spent / math.max(1, now.day) * daysInMonth).round();
    }
    return BudgetForecast(spentCents: spent, projectedCents: projected, budgetCents: budgetCents);
  }

  // -------------------------------------------------------------------- outages

  static int _slot(DateTime t) => (t.weekday - 1) * 24 + t.hour;

  static bool _isOutage(ServiceReport r, Service s) =>
      r.service == s && (r.status == ReportStatus.off || r.status == ReportStatus.lowPressure);

  static int _weeksObserved(List<ServiceReport> relevant, DateTime now) {
    final earliest = relevant.map((r) => r.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    return math.min(8, now.difference(earliest).inDays ~/ 7 + 1);
  }

  /// Probability (0..1) of an outage in each of the 168 hours of the week.
  /// Neighbours reporting the same outage count once; recent weeks count more.
  List<double> hourOfWeekProbability(List<ServiceReport> reports, Service service, DateTime now) {
    final relevant = reports
        .where((r) => _isOutage(r, service) && r.startedAt.isBefore(now) && now.difference(r.startedAt).inDays < 56)
        .toList();
    final prob = List<double>.filled(168, 0);
    if (relevant.isEmpty) return prob;
    final weeks = _weeksObserved(relevant, now);

    final seen = <int>{};
    for (final r in relevant) {
      var end = r.restoredAt ?? r.startedAt.add(const Duration(hours: 2));
      if (end.difference(r.startedAt).inHours > 24) end = r.startedAt.add(const Duration(hours: 24));
      var h = DateTime(r.startedAt.year, r.startedAt.month, r.startedAt.day, r.startedAt.hour);
      while (h.isBefore(end)) {
        final week = now.difference(h).inDays ~/ 7;
        if (week >= 0 && week < weeks) seen.add(week * 168 + _slot(h));
        h = h.add(const Duration(hours: 1));
      }
    }

    final weekWeights = List<double>.generate(weeks, (k) => math.pow(0.85, k).toDouble());
    final total = weekWeights.fold(0.0, (s, w) => s + w);
    for (final key in seen) {
      prob[key % 168] += weekWeights[key ~/ 168] / total;
    }
    return List<double>.generate(168, (s) {
      final prev = prob[(s + 167) % 168];
      final next = prob[(s + 1) % 168];
      return math.min(1.0, 0.2 * prev + 0.6 * prob[s] + 0.2 * next);
    });
  }

  List<OutageWindow> outageWindows(
    List<ServiceReport> reports,
    Service service,
    DateTime now, {
    double threshold = 0.35,
    int horizonHours = 168,
  }) {
    final relevant = reports.where((r) => _isOutage(r, service) && r.startedAt.isBefore(now)).toList();
    if (relevant.isEmpty) return const [];
    final prob = hourOfWeekProbability(reports, service, now);
    final weeks = _weeksObserved(relevant, now);

    final windows = <OutageWindow>[];
    DateTime? start;
    var peak = 0.0;
    final firstHour = DateTime(now.year, now.month, now.day, now.hour);
    for (var i = 0; i <= horizonHours; i++) {
      final t = firstHour.add(Duration(hours: i));
      final p = i == horizonHours ? 0.0 : prob[_slot(t)];
      if (p >= threshold) {
        start ??= t;
        peak = math.max(peak, p);
      } else if (start != null) {
        windows.add(OutageWindow(service: service, start: start, end: t, probability: peak, weeksObserved: weeks));
        start = null;
        peak = 0;
      }
    }
    return windows;
  }

  DurationStats? outageDuration(List<ServiceReport> reports, Service service) {
    final hours = reports
        .where((r) => r.service == service && r.restoredAt != null && r.status.isDisruption)
        .map((r) => r.restoredAt!.difference(r.startedAt).inMinutes / 60)
        .where((h) => h > 0 && h < 72)
        .toList()
      ..sort();
    if (hours.length < 3) return null;
    double at(double q) => hours[((hours.length - 1) * q).round()];
    return DurationStats(medianHours: at(0.5), p80Hours: at(0.8), sample: hours.length);
  }

  // --------------------------------------------------------------- daily usage

  /// kWh used per calendar day over the last [days] days (days without
  /// enough readings are left out).
  List<DailyUsage> dailyUsage(List<Reading> readings, List<Topup> topups, DateTime now, {int days = 14}) {
    final units = readings.where((r) => r.kind == ReadingKind.elecUnits && !r.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final rates = <({DateTime from, DateTime to, double perDay})>[];
    for (var i = 1; i < units.length; i++) {
      final a = units[i - 1];
      final b = units[i];
      final span = b.at.difference(a.at).inMinutes / (60 * 24);
      if (span < 0.25) continue;
      final bought = topups.where((t) => t.date.isAfter(a.at) && !t.date.isAfter(b.at)).fold(0.0, (s, t) => s + t.units);
      final used = a.value + bought - b.value;
      if (used >= 0) rates.add((from: a.at, to: b.at, perDay: used / span));
    }
    final today = DateTime(now.year, now.month, now.day);
    final out = <DailyUsage>[];
    for (var d = days; d >= 1; d--) {
      final day = today.subtract(Duration(days: d));
      final noon = day.add(const Duration(hours: 12));
      double? perDay;
      for (final r in rates) {
        if (!noon.isBefore(r.from) && !noon.isAfter(r.to)) perDay = r.perDay;
      }
      if (perDay != null) out.add(DailyUsage(day, perDay));
    }
    return out;
  }

  /// Change in average daily use: last 14 days vs the 14 days before.
  double? usageChange(List<Reading> readings, List<Topup> topups, DateTime now) {
    final all = dailyUsage(readings, topups, now, days: 28);
    final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 14));
    final recent = all.where((d) => !d.day.isBefore(cutoff)).map((d) => d.kwh).toList();
    final before = all.where((d) => d.day.isBefore(cutoff)).map((d) => d.kwh).toList();
    if (recent.length < 5 || before.length < 5) return null;
    final recentAvg = recent.reduce((x, y) => x + y) / recent.length;
    final beforeAvg = before.reduce((x, y) => x + y) / before.length;
    return beforeAvg <= 0 ? null : (recentAvg - beforeAvg) / beforeAvg;
  }

  // -------------------------------------------------------------------- impact

  HouseholdImpact householdImpact({
    required List<Prediction> history,
    required List<Reading> readings,
    required List<Topup> topups,
    required int storageLitres,
    required int people,
    required DateTime now,
  }) {
    final outages = history.where((p) => p.isCheckable && !p.from.isAfter(now)).toList();
    final warned = outages.where((p) => p.cameTrue).toList();
    final leads = warned.where((p) => p.issuedAt != null).map((p) => p.from.difference(p.issuedAt!).inMinutes / 60).toList();
    final checked = outages.where((p) => p.feedback != null).toList();
    final score = checked.fold(0.0, (s, p) => s + (p.feedback == 'yes' ? 1.0 : p.feedback == 'partly' ? 0.5 : 0.0));
    final litres = storageLitres > 0 ? storageLitres : (math.max(20, people * 15) / 10).ceil() * 10;
    final waterActed = warned.where((p) => p.type == PredictionType.waterOutage && p.acted).length;
    final firsts = [
      ...history.map((p) => p.issuedAt ?? p.from),
      ...readings.map((r) => r.at),
    ];
    final since = firsts.isEmpty ? 0 : now.difference(firsts.reduce((a, b) => a.isBefore(b) ? a : b)).inDays;
    return HouseholdImpact(
      sinceDays: since,
      outagesWarned: warned.length,
      avgWarningHours: leads.isEmpty ? null : leads.reduce((a, b) => a + b) / leads.length,
      forecastsChecked: checked.length,
      accuracy: checked.isEmpty ? null : score / checked.length,
      litresStored: waterActed * litres,
      runOutsAvoided: history.where((p) => p.type == PredictionType.elecRunout && p.acted && p.from.isBefore(now)).length,
      usageChange: usageChange(readings, topups, now),
    );
  }

  AreaSummary areaSummary(List<ServiceReport> reports, DateTime now) {
    final recent = reports.where((r) => now.difference(r.startedAt).inDays < 56).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    // Same service and status starting within 3 hours = one outage.
    var outages = 0;
    final lastStart = <String, DateTime>{};
    for (final r in recent.where((r) => r.status.isDisruption)) {
      final key = '${r.service.wire}/${r.status.wire}';
      final prev = lastStart[key];
      if (prev == null || r.startedAt.difference(prev).inHours >= 3) {
        outages++;
        lastStart[key] = r.startedAt;
      }
    }
    String? worst;
    var worstP = 0.0;
    for (final s in Service.values) {
      final prob = hourOfWeekProbability(reports, s, now);
      for (var slot = 0; slot < 168; slot++) {
        if (prob[slot] > worstP) {
          worstP = prob[slot];
          final day = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][slot ~/ 24];
          worst = '$day ${two(slot % 24)}:00 · ${s.label.toLowerCase()}';
        }
      }
    }
    final weeks = recent.isEmpty ? 0 : math.min(8, now.difference(recent.first.startedAt).inDays ~/ 7 + 1);
    return AreaSummary(
      households: recent.map((r) => r.reporter).toSet().length,
      reports: recent.length,
      outages: outages,
      weeks: weeks,
      water: outageDuration(recent, Service.water),
      power: outageDuration(recent, Service.electricity),
      worstTime: worstP >= 0.35 ? worst : null,
    );
  }

  // ----------------------------------------------------------- home-screen cards

  List<Prediction> homePredictions({
    required Household household,
    required List<ServiceReport> reports,
    required List<Reading> readings,
    required List<Topup> topups,
    required DateTime now,
    int hours = 48,
  }) {
    final out = <Prediction>[];
    final horizon = now.add(Duration(hours: hours));

    for (final service in Service.values) {
      final duration = outageDuration(reports, service);
      for (final w in outageWindows(reports, service, now)) {
        if (w.start.isAfter(horizon)) continue;
        final isWater = service == Service.water;
        final prepBy = w.start.subtract(const Duration(hours: 1));
        final litres = household.storageLitres > 0
            ? household.storageLitres
            : (math.max(20, household.people * 15) / 10).ceil() * 10;
        final typical = duration == null ? '' : ' Usually back within about ${hoursLabel(duration.p80Hours)}.';
        out.add(Prediction(
          id: '${isWater ? PredictionType.waterOutage.wire : PredictionType.powerOutage.wire}_${w.start.toIso8601String()}',
          type: isWater ? PredictionType.waterOutage : PredictionType.powerOutage,
          service: service,
          title: '${service.label} likely off ${whenLabel(w.start, now)} to ${hhmm(w.end)}',
          detail: 'Based on ${w.weeksObserved} weeks of reports in ${household.areaName}.$typical',
          action: isWater ? 'Fill $litres L before ${hhmm(prepBy)}' : 'Charge phones and lights before ${hhmm(prepBy)}',
          probability: w.probability,
          from: w.start,
          to: w.end,
        ));
      }
    }

    if (household.prepaid) {
      final f = electricity(readings, topups, now);
      if (f != null && f.daysLeft <= 7) {
        final days = f.daysLeft.round();
        out.add(Prediction(
          id: '${PredictionType.elecRunout.wire}_${DateTime(now.year, now.month, now.day).toIso8601String()}',
          type: PredictionType.elecRunout,
          service: Service.electricity,
          title: days < 1 ? 'Electricity runs out today' : 'Electricity runs out in about $days day${days == 1 ? '' : 's'} (${weekday(f.runOut)})',
          detail: 'About ${f.unitsLeft.toStringAsFixed(0)} kWh left; you use about ${f.dailyKwh.toStringAsFixed(1)} kWh a day.',
          action: 'Buy ${rands(f.suggestedTopupCents)} before ${weekday(f.runOut)}',
          from: f.runOut,
        ));
      }
      final b = electricityBudget(household.electricityBudgetCents, topups, f, now);
      if (b != null && b.isOver) {
        out.add(Prediction(
          id: '${PredictionType.budgetOverspend.wire}_${now.year}_${now.month}',
          type: PredictionType.budgetOverspend,
          service: Service.electricity,
          title: 'On track to spend ${rands(b.projectedCents)} on electricity',
          detail: '${rands(b.overCents)} over your ${rands(b.budgetCents)} budget this month.',
          action: 'Switch the geyser to 2 hours a day to save about ${rands(((f?.tariff ?? defaultTariffRandsPerKwh) * 2 * 30 * 100).round())}',
          from: DateTime(now.year, now.month + 1, 0),
        ));
      }
    }
    return out;
  }
}
