import 'package:flutter_test/flutter_test.dart';
import 'package:street_signal/core/enums.dart';
import 'package:street_signal/logic/pilot_history.dart';
import 'package:street_signal/models/community.dart';
import 'package:street_signal/logic/prediction_engine.dart';
import 'package:street_signal/models/household.dart';
import 'package:street_signal/models/records.dart';

void main() {
  const engine = PredictionEngine();

  group('electricity', () {
    test('estimates daily use and days left from unit readings', () {
      final readings = [
        Reading(id: 'a', kind: ReadingKind.elecUnits, value: 100, at: DateTime(2026, 10, 20, 7)),
        Reading(id: 'b', kind: ReadingKind.elecUnits, value: 80, at: DateTime(2026, 10, 22, 7)),
        Reading(id: 'c', kind: ReadingKind.elecUnits, value: 60, at: DateTime(2026, 10, 24, 7)),
      ];
      final f = engine.electricity(readings, const [], DateTime(2026, 10, 24, 19))!;
      expect(f.dailyKwh, closeTo(10, 0.01));
      expect(f.unitsLeft, closeTo(55, 0.1));
      expect(f.daysLeft, closeTo(5.5, 0.05));
    });

    test('counts units bought between readings', () {
      final readings = [
        Reading(id: 'a', kind: ReadingKind.elecUnits, value: 20, at: DateTime(2026, 10, 20, 7)),
        Reading(id: 'b', kind: ReadingKind.elecUnits, value: 100, at: DateTime(2026, 10, 22, 7)),
      ];
      final topups = [Topup(id: 't', date: DateTime(2026, 10, 21, 9), amountCents: 34000, units: 100)];
      final f = engine.electricity(readings, topups, DateTime(2026, 10, 22, 7))!;
      expect(f.dailyKwh, closeTo(10, 0.01)); // 20 + 100 - 100 = 20 kWh over 2 days
      expect(f.tariff, closeTo(3.40, 0.001));
    });

    test('needs at least two readings', () {
      final one = [Reading(id: 'a', kind: ReadingKind.elecUnits, value: 50, at: DateTime(2026, 10, 20))];
      expect(engine.electricity(one, const [], DateTime(2026, 10, 21)), isNull);
    });
  });

  group('outages', () {
    // Water off every Tuesday 18:00 to 22:00 for four weeks.
    final reports = [
      for (final day in [DateTime(2026, 9, 29), DateTime(2026, 10, 6), DateTime(2026, 10, 13), DateTime(2026, 10, 20)])
        ServiceReport(
          id: 'r${day.day}',
          uid: 'u',
          areaId: 'a',
          service: Service.water,
          status: ReportStatus.off,
          startedAt: day.add(const Duration(hours: 18)),
          restoredAt: day.add(const Duration(hours: 22)),
        ),
    ];
    final monday = DateTime(2026, 10, 26, 12);

    test('predicts next Tuesday evening', () {
      final windows = engine.outageWindows(reports, Service.water, monday);
      expect(windows, hasLength(1));
      expect(windows.first.start, DateTime(2026, 10, 27, 18));
      expect(windows.first.end, DateTime(2026, 10, 27, 22));
      expect(windows.first.probability, greaterThan(0.9));
      expect(windows.first.weeksObserved, 4);
    });

    test('does not predict other services', () {
      expect(engine.outageWindows(reports, Service.electricity, monday), isEmpty);
    });

    test('typical duration', () {
      final d = engine.outageDuration(reports, Service.water)!;
      expect(d.medianHours, closeTo(4, 0.01));
    });
  });

  group('pilot history', () {
    // A Sunday morning: last week's outages are in the past.
    final now = DateTime(2026, 10, 25, 9);
    var n = 0;
    final pilot = PilotHistory.generate(
      areaId: 'soweto',
      areaName: 'Soweto',
      uid: 'me',
      now: now,
      newId: () => 'p${n++}',
      people: 4,
      storageLitres: 60,
    );
    final home = Household(id: 'me', ownerUid: 'me', displayName: 'T', areaId: 'soweto', areaName: 'Soweto', people: 4, storageLitres: 60);

    test('looks like a real ward: many households, many reports, all flagged', () {
      expect(pilot.reports.every((r) => r.pilot && r.uid == 'me' && r.restoredAt != null), isTrue);
      final households = pilot.reports.map((r) => r.reporter).toSet().length;
      expect(households, greaterThan(30));
      expect(pilot.reports.length, inInclusiveRange(150, 350));
    });

    test('leaves the household about 3 days of electricity, with lower use lately', () {
      final f = engine.electricity(pilot.readings, pilot.topups, now)!;
      expect(f.daysLeft, inInclusiveRange(2.0, 5.0));
      final change = engine.usageChange(pilot.readings, pilot.topups, now)!;
      expect(change, lessThan(-0.05));
    });

    test('impact numbers are meaningful and honest', () {
      final impact = engine.householdImpact(
        history: pilot.predictions,
        readings: pilot.readings,
        topups: pilot.topups,
        storageLitres: 60,
        people: 4,
        now: now,
      );
      expect(impact.outagesWarned, greaterThan(5));
      expect(impact.accuracy, isNotNull);
      expect(impact.accuracy!, lessThan(1.0)); // includes misses
      expect(impact.litresStored, greaterThan(0));
      expect(impact.runOutsAvoided, greaterThan(0));
    });

    test('area summary counts outages, not reports', () {
      final area = engine.areaSummary(pilot.reports, now);
      expect(area.outages, inInclusiveRange(20, 40));
      expect(area.reports, greaterThan(area.outages));
      expect(area.worstTime, isNotNull);
    });

    test('reports carry the fields the dashboard charts need', () {
      final m = pilot.reports.first.toMap();
      for (final key in ['areaId', 'areaName', 'ward', 'householdId', 'people', 'service', 'status',
          'startedAt', 'restoredAt', 'durationMinutes', 'day', 'weekday', 'hour', 'source']) {
        expect(m.containsKey(key), isTrue, reason: key);
      }
      expect(m['source'], 'pilot');
      expect(m['durationMinutes'], greaterThan(0));
    });

    test('community posts cover all five sectors and carry dashboard fields', () {
      expect(pilot.posts.map((p) => p.sector).toSet(), Sector.values.toSet());
      expect(pilot.posts.every((p) => p.pilot && p.uid == 'me'), isTrue);
      final m = pilot.posts.firstWhere((p) => p.target != null).toMap();
      for (final key in ['areaId', 'sector', 'topic', 'kind', 'title', 'members', 'target', 'open', 'createdAt', 'day', 'source']) {
        expect(m.containsKey(key), isTrue, reason: key);
      }
      expect(pilot.posts.any((p) => p.quality == WaterQuality.cloudy), isTrue);
    });

    test('produces a forecast card on the Home screen', () {
      final cards = engine.homePredictions(household: home, reports: pilot.reports, readings: pilot.readings, topups: pilot.topups, now: now);
      expect(cards.any((p) => p.type == PredictionType.elecRunout), isTrue);
      expect(cards.any((p) => p.type == PredictionType.powerOutage), isTrue); // Monday evening within 48 h
    });
  });
}
