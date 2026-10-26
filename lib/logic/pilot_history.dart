// An 8-week pilot for one ward, so the app shows real benefit on day one.
//
// Everything here is flagged `pilot: true` and can be removed later. It is
// shaped like a real South African township pilot:
//  * 46 households reporting, several reports per outage.
//  * Regular patterns the app can learn: water off Tuesday evenings, low
//    pressure Thursday and Saturday mornings, power off Monday and Wednesday
//    evenings (load reduction), each on most but not all weeks.
//  * Two unplanned outages (a burst main and cable theft) that no forecast
//    could predict, so the record stays honest.
//  * This household's last 6 weeks: meter readings, top-ups, lower use after
//    following a saving tip, and a forecast track record including a miss.
import 'dart:math' as math;

import '../core/enums.dart';
import '../core/format.dart';
import '../models/community.dart';
import '../models/records.dart';

class PilotHistory {
  PilotHistory({required this.reports, required this.readings, required this.topups, required this.predictions, this.posts = const []});
  final List<ServiceReport> reports;
  final List<Reading> readings;
  final List<Topup> topups;
  final List<Prediction> predictions;
  final List<CommunityPost> posts;

  static const pilotHouseholds = 46;
  static const pilotWeeks = 8;

  static PilotHistory generate({
    required String areaId,
    required String areaName,
    String ward = '',
    required String uid,
    required DateTime now,
    required String Function() newId,
    int people = 4,
    int storageLitres = 0,
    bool prepaid = true,
  }) {
    final rnd = math.Random(areaId.hashCode ^ 0x5157);
    final today = DateTime(now.year, now.month, now.day);
    final reports = <ServiceReport>[];
    final predictions = <Prediction>[];
    final litres = storageLitres > 0 ? storageLitres : (math.max(20, people * 15) / 10).ceil() * 10;

    List<String> householdsFor(int n) {
      final pool = List<int>.generate(pilotHouseholds, (i) => i + 1)..shuffle(rnd);
      return [for (final i in pool.take(n)) 'hh-${i.toString().padLeft(3, '0')}'];
    }

    // Each pilot household has a fixed size (2 to 7 people).
    int peopleIn(String household) => 2 + household.hashCode.abs() % 6;

    void outage({
      required Service service,
      required ReportStatus status,
      required DateTime start,
      required Duration length,
      required int reporters,
      String note = '',
    }) {
      final end = start.add(length);
      if (!end.isBefore(now)) return; // only finished outages
      final who = householdsFor(reporters);
      for (var i = 0; i < who.length; i++) {
        reports.add(ServiceReport(
          id: newId(),
          uid: uid,
          areaId: areaId,
          areaName: areaName,
          ward: ward,
          people: peopleIn(who[i]),
          service: service,
          status: status,
          startedAt: start.add(Duration(minutes: 3 + rnd.nextInt(45))),
          restoredAt: end.add(Duration(minutes: rnd.nextInt(30))),
          note: i == 0 ? note : '',
          pilot: true,
          pilotHousehold: who[i],
        ));
      }
    }

    // ---------------------------------------------------------- regular patterns
    // (weekday, hour, length h, chance, min..max reporters, service, status, predictable)
    final patterns = <({int weekday, int hour, double hours, double chance, int minR, int maxR, Service service, ReportStatus status})>[
      (weekday: DateTime.tuesday, hour: 18, hours: 4, chance: 0.85, minR: 6, maxR: 14, service: Service.water, status: ReportStatus.off),
      (weekday: DateTime.thursday, hour: 6, hours: 3, chance: 0.6, minR: 3, maxR: 7, service: Service.water, status: ReportStatus.lowPressure),
      (weekday: DateTime.saturday, hour: 7, hours: 3, chance: 0.65, minR: 3, maxR: 6, service: Service.water, status: ReportStatus.lowPressure),
      (weekday: DateTime.monday, hour: 17, hours: 2.5, chance: 0.85, minR: 5, maxR: 12, service: Service.electricity, status: ReportStatus.off),
      (weekday: DateTime.wednesday, hour: 17, hours: 2.5, chance: 0.85, minR: 5, maxR: 12, service: Service.electricity, status: ReportStatus.off),
    ];

    for (final p in patterns) {
      for (var week = 0; week < pilotWeeks; week++) {
        final monday = today.subtract(Duration(days: today.weekday - 1 + 7 * week));
        final slot = monday.add(Duration(days: p.weekday - 1, hours: p.hour));
        final windowEnd = slot.add(Duration(minutes: (p.hours * 60).round()));
        if (!windowEnd.isBefore(now)) continue;
        final happened = rnd.nextDouble() < p.chance;
        if (happened) {
          outage(
            service: p.service,
            status: p.status,
            start: slot.add(Duration(minutes: rnd.nextInt(15))),
            length: Duration(minutes: ((p.hours + (rnd.nextDouble() - 0.5) * 1.2) * 60).round()),
            reporters: p.minR + rnd.nextInt(p.maxR - p.minR + 1),
          );
        }

        // Forecast track record for the last 5 weeks of the main patterns
        // (the first weeks of a pilot are spent learning).
        final isMain = p.status == ReportStatus.off;
        if (isMain && week < 5) {
          final isWater = p.service == Service.water;
          final type = isWater ? PredictionType.waterOutage : PredictionType.powerOutage;
          final issued = slot.subtract(Duration(hours: 22 + rnd.nextInt(6)));
          // Most recent past forecast is left unanswered so "Did this happen?" shows.
          final unanswered = week == 0 || (week == 1 && slot.isAfter(now.subtract(const Duration(days: 4))));
          final feedback = unanswered ? null : (happened ? (rnd.nextDouble() < 0.12 ? 'partly' : 'yes') : 'no');
          predictions.add(Prediction(
            id: '${type.wire}_${slot.toIso8601String()}',
            type: type,
            service: p.service,
            title: '${p.service.label} likely off ${weekday(slot)} ${hhmm(slot)} to ${hhmm(windowEnd)}',
            detail: 'Forecast from area reports.',
            action: isWater ? 'Fill $litres L before ${hhmm(slot.subtract(const Duration(hours: 1)))}' : 'Charge phones and lights before ${hhmm(slot.subtract(const Duration(hours: 1)))}',
            probability: 0.7 + rnd.nextInt(20) / 100,
            from: slot,
            to: windowEnd,
            feedback: feedback,
            issuedAt: issued,
            acted: rnd.nextDouble() < 0.8,
          ));
        }
      }
    }

    // An honest record includes misses: make sure at least one answered
    // forecast was only partly right.
    final answered = predictions.where((p) => p.feedback != null).toList()..sort((a, b) => a.from.compareTo(b.from));
    if (answered.isNotEmpty && answered.every((p) => p.feedback == 'yes')) {
      final i = predictions.indexOf(answered.first);
      predictions[i] = predictions[i].copyWith(feedback: 'partly');
    }

    // ------------------------------------------------------- unplanned outages
    outage(
      service: Service.water,
      status: ReportStatus.off,
      start: today.subtract(const Duration(days: 13)).add(const Duration(hours: 9, minutes: 20)),
      length: const Duration(hours: 31),
      reporters: 18,
      note: 'Burst main on the main road',
    );
    outage(
      service: Service.electricity,
      status: ReportStatus.off,
      start: today.subtract(const Duration(days: 9)).add(const Duration(hours: 20, minutes: 5)),
      length: const Duration(hours: 14),
      reporters: 15,
      note: 'Cable theft at the substation',
    );

    // ------------------------------------------------- this household's meter
    final readings = <Reading>[];
    final topups = <Topup>[];
    if (prepaid) {
      final meter = _meter(today: today, now: now, seed: areaId.hashCode, newId: newId);
      readings.addAll(meter.readings);
      topups.addAll(meter.topups);
      // Each top-up followed a "runs out soon" warning: run-outs avoided.
      for (final t in meter.topups) {
        final warned = t.date.subtract(const Duration(days: 1, hours: 14));
        if (warned.isBefore(today.subtract(const Duration(days: 42)))) continue;
        final runOut = t.date.add(const Duration(days: 1, hours: 6));
        predictions.add(Prediction(
          id: '${PredictionType.elecRunout.wire}_${DateTime(warned.year, warned.month, warned.day).toIso8601String()}',
          type: PredictionType.elecRunout,
          service: Service.electricity,
          title: 'Electricity runs out in about 3 days (${weekday(runOut)})',
          detail: 'Pilot forecast.',
          action: 'Buy ${rands(t.amountCents)} before ${weekday(runOut)}',
          from: runOut,
          issuedAt: warned,
          acted: true,
        ));
      }
    }

    final posts = _posts(areaId: areaId, areaName: areaName, ward: ward, uid: uid, now: now, newId: newId);
    return PilotHistory(reports: reports, readings: readings, topups: topups, predictions: predictions, posts: posts);
  }

  /// A handful of community posts across all five sectors.
  static List<CommunityPost> _posts({
    required String areaId,
    required String areaName,
    required String ward,
    required String uid,
    required DateTime now,
    required String Function() newId,
  }) {
    List<String> members(int n, int seed) => [for (var i = 0; i < n; i++) 'hh-${((seed * 7 + i * 5) % 46 + 1).toString().padLeft(3, '0')}'];
    CommunityPost post(
      String topic,
      String name,
      String title, {
      String details = '',
      String place = '',
      int hoursAgo = 2,
      int? expiresInHours,
      int joined = 0,
      int? target,
      WaterQuality? quality,
    }) {
      final created = now.subtract(Duration(hours: hoursAgo));
      return CommunityPost(
        id: newId(),
        uid: uid,
        displayName: name,
        areaId: areaId,
        areaName: areaName,
        ward: ward,
        topic: PostTopic.byId(topic),
        title: title,
        details: details,
        place: place,
        quality: quality,
        target: target,
        members: members(joined, hoursAgo),
        createdAt: created,
        expiresAt: expiresInHours == null ? null : now.add(Duration(hours: expiresInHours)),
        pilot: true,
        pilotHousehold: 'hh-${(name.hashCode.abs() % 46 + 1).toString().padLeft(3, '0')}',
      );
    }

    return [
      // Food
      post('food_place', 'Kagiso', 'Community garden behind the clinic',
          details: 'Spinach, tomatoes and onions. Open Tue and Sat mornings; bring a bag.', place: 'Behind the clinic', hoursAgo: 70, joined: 9),
      post('food_group', 'Lerato', 'Maize meal 50 kg, split 5 ways',
          details: 'R95 per household instead of R130 in the shop. Collect at my place on Saturday.', place: 'Near the taxi rank', hoursAgo: 20, joined: 3, target: 5, expiresInHours: 72),
      post('food_surplus', 'Ayesha', '20 loaves from the bakery, free after 17:00',
          details: 'Yesterday\'s bread, still good. First come, first served.', place: 'Bakery on the main road', hoursAgo: 3, joined: 6, expiresInHours: 10),
      // Energy
      post('energy_charging', 'Sipho', 'Solar phone charging at the spaza',
          details: 'Free during power cuts, R2 otherwise.', place: 'Spaza next to the clinic', hoursAgo: 30, joined: 14),
      post('energy_group', 'Musa', '9 kg gas refills at bulk price',
          details: 'R310 each if 8 households join (normally R365). Delivery on Thursday.', place: 'Ward 12', hoursAgo: 26, joined: 5, target: 8, expiresInHours: 96),
      // Water
      post('water_quality', 'Palesa', 'Tap water brown on 5th Street',
          details: 'Since the burst main was fixed. Boiling before drinking for now.', place: '5th Street', hoursAgo: 5, joined: 4, quality: WaterQuality.cloudy),
      post('water_quality', 'Johan', 'Tap water clear again near the school',
          details: 'Tested with a kit from the clinic: fine.', place: 'Near the school', hoursAgo: 1, joined: 2, quality: WaterQuality.clear),
      post('water_share', 'Johan', '200 L in my JoJo tank',
          details: 'Bring your own containers, after 17:00 on Tuesday.', place: 'Corner of 2nd and Main', hoursAgo: 8, joined: 3, expiresInHours: 48),
      // Transport
      post('ride_offer', 'Thabo', 'To town, Monday 07:00, 3 seats',
          details: 'R20 towards petrol.', place: 'Leaving from the church', hoursAgo: 12, joined: 2, expiresInHours: 40),
      post('ride_request', 'Nomsa', 'To the clinic, Friday 09:00',
          details: 'For my mother, she uses a walker.', place: 'Ward 12', hoursAgo: 16, joined: 1, expiresInHours: 80),
      post('lend_item', 'Sipho', 'Wheelbarrow and spade to borrow',
          details: 'For the weekend. Just bring them back clean.', place: 'Near the spaza', hoursAgo: 50, joined: 2),
      post('access_issue', 'Palesa', 'Flooded road by the bridge',
          details: 'Not safe for prams or wheelchairs; use the main road.', place: 'Bridge on 3rd Avenue', hoursAgo: 6, joined: 7),
      // Prepare
      post('prepare_offer', 'Musa', 'Generator for medical equipment in a power cut',
          details: 'Call me day or night if someone needs power for equipment.', place: 'Ward 12', hoursAgo: 90, joined: 3),
    ];
  }

  /// Six weeks of prepaid use: about 12.5 kWh a day (15.5 at weekends) until
  /// three weeks ago, then about 10 (12.5) after switching the geyser to a
  /// timer. R300 top-ups whenever the units drop low. The starting balance is
  /// tuned so that about 3 days of electricity are left today.
  static ({List<Reading> readings, List<Topup> topups}) _meter({
    required DateTime today,
    required DateTime now,
    required int seed,
    required String Function() newId,
  }) {
    const days = 42;
    const amount = 30000; // R300
    const bought = 88.8; // at about R3.38 per kWh

    double use(DateTime day, math.Random r) {
      final weekend = day.weekday >= DateTime.saturday;
      final saving = today.difference(day).inDays < 21;
      final base = saving ? (weekend ? 12.5 : 10.0) : (weekend ? 15.5 : 12.5);
      return base + (r.nextDouble() - 0.5) * 1.6;
    }

    ({double end, List<DateTime> buys}) simulate(double start) {
      final r = math.Random(seed);
      var units = start;
      final buys = <DateTime>[];
      for (var d = days; d >= 1; d--) {
        final day = today.subtract(Duration(days: d));
        units -= use(day, r);
        if (units < 22) {
          buys.add(day.add(const Duration(hours: 18)));
          units += bought;
        }
      }
      return (end: units, buys: buys);
    }

    // Pick the starting balance that leaves about 32 kWh this morning.
    var start = 40.0;
    var best = double.infinity;
    for (var s = 30.0; s <= 110; s += 1) {
      final gap = (simulate(s).end - 32).abs();
      if (gap < best) {
        best = gap;
        start = s;
      }
    }

    final r = math.Random(seed);
    var units = start;
    final readings = <Reading>[];
    final topups = <Topup>[];
    for (var d = days; d >= 0; d--) {
      final day = today.subtract(Duration(days: d));
      final morning = day.add(const Duration(hours: 7));
      if (morning.isAfter(now)) break;
      if (d % 2 == 0 || d <= 2) {
        readings.add(Reading(id: newId(), kind: ReadingKind.elecUnits, value: double.parse(units.toStringAsFixed(1)), at: morning));
      }
      if (d == 0) break;
      units -= use(day, r);
      if (units < 22) {
        topups.add(Topup(id: newId(), date: day.add(const Duration(hours: 18)), amountCents: amount, units: bought));
        units += bought;
      }
    }
    return (readings: readings, topups: topups);
  }
}
