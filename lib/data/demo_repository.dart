import 'dart:async';

import '../core/enums.dart';
import '../logic/pilot_history.dart';
import '../models/community.dart';
import '../models/household.dart';
import '../models/records.dart';
import 'repository.dart';

/// In-memory data source for demo mode and tests. Picking an area loads the
/// small pilot history automatically and one alert from the ward.
class DemoRepository implements Repository {
  DemoRepository({this.uid = 'demo-user', DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  @override
  final String uid;
  final DateTime Function() _clock;
  int _seq = 0;

  Household? _household;
  final List<ServiceReport> _reports = [];
  final List<AlertItem> _alerts = [];
  final Map<String, List<Topup>> _topups = {};
  final Map<String, List<Reading>> _readings = {};
  final Map<String, List<Prediction>> _predictions = {};
  final List<CommunityPost> _posts = [];
  final Map<String, List<HouseholdNeed>> _needs = {};
  final Set<String> _seeded = {};
  final _changes = StreamController<void>.broadcast();

  @override
  bool get isDemo => true;

  @override
  String newId() => 'id${_clock().microsecondsSinceEpoch}_${_seq++}';

  void _notify() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Future<Household?> loadHousehold() async => _household;

  @override
  Future<void> saveHousehold(Household household) async {
    _household = household;
    if (_seeded.add(household.areaId)) {
      final now = _clock();
      await savePilotHistory(
        household.id,
        PilotHistory.generate(
          areaId: household.areaId,
          areaName: household.areaName,
          ward: household.ward,
          uid: uid,
          now: now,
          newId: newId,
          people: household.people,
          storageLitres: household.storageLitres,
          prepaid: household.prepaid,
        ),
      );
      _alerts.addAll([
        AlertItem(
          id: newId(),
          areaIds: [household.areaId],
          service: Service.water,
          title: 'Planned maintenance: water off Thursday 09:00 to 15:00',
          body: 'The municipality is replacing a valve on the main line. Store water on Wednesday night.',
          source: AlertSource.official,
          sentAt: now.subtract(const Duration(hours: 5)),
        ),
        AlertItem(
          id: newId(),
          areaIds: [household.areaId],
          service: Service.electricity,
          title: 'Substation cable replaced after theft',
          body: 'Ward 12 confirmed power is fully restored. Thank you to the 15 households who reported it.',
          source: AlertSource.official,
          sentAt: now.subtract(const Duration(days: 8, hours: 9)),
        ),
      ]);
    }
    _notify();
  }

  @override
  Stream<List<ServiceReport>> watchAreaReports(String areaId) => _watch(() {
        final list = _reports.where((r) => r.areaId == areaId).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return list;
      });

  @override
  Future<void> addReport(ServiceReport report) async {
    _reports.add(report);
    _notify();
  }

  @override
  Future<void> markRestored(ServiceReport report, DateTime at) async {
    final i = _reports.indexWhere((r) => r.id == report.id);
    if (i >= 0) _reports[i] = _reports[i].copyWith(restoredAt: at);
    _notify();
  }

  @override
  Stream<List<AlertItem>> watchAlerts(String areaId) => _watch(() {
        final list = _alerts.where((a) => a.areaIds.contains(areaId)).toList()
          ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
        return list;
      });

  @override
  Future<List<Topup>> loadTopups(String householdId) async => [...?_topups[householdId]];

  @override
  Future<void> addTopup(String householdId, Topup topup) async => _topups.putIfAbsent(householdId, () => []).add(topup);

  @override
  Future<List<Reading>> loadReadings(String householdId) async => [...?_readings[householdId]];

  @override
  Future<void> addReading(String householdId, Reading reading) async =>
      _readings.putIfAbsent(householdId, () => []).add(reading);

  @override
  Future<List<Prediction>> loadPredictions(String householdId) async => [...?_predictions[householdId]];

  @override
  Future<void> savePrediction(String householdId, Prediction prediction) async {
    final list = _predictions.putIfAbsent(householdId, () => []);
    list.removeWhere((p) => p.id == prediction.id);
    list.add(prediction);
  }

  @override
  Stream<List<CommunityPost>> watchPosts(String areaId) => _watch(() {
        final list = _posts.where((p) => p.areaId == areaId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  @override
  Future<void> addPost(CommunityPost post) async {
    _posts.add(post);
    _notify();
  }

  @override
  Future<void> setMember(CommunityPost post, bool join) async {
    final i = _posts.indexWhere((p) => p.id == post.id);
    if (i < 0) return;
    final members = [..._posts[i].members.where((m) => m != uid), if (join) uid];
    _posts[i] = _posts[i].copyWith(members: members);
    _notify();
  }

  @override
  Future<void> closePost(CommunityPost post) async {
    final i = _posts.indexWhere((p) => p.id == post.id);
    if (i >= 0) _posts[i] = _posts[i].copyWith(open: false);
    _notify();
  }

  @override
  Future<List<HouseholdNeed>> loadNeeds(String householdId) async => [...?_needs[householdId]];

  @override
  Future<void> addNeed(String householdId, HouseholdNeed need) async => _needs.putIfAbsent(householdId, () => []).add(need);

  @override
  Future<void> removeNeed(String householdId, String needId) async => _needs[householdId]?.removeWhere((n) => n.id == needId);

  @override
  Future<void> savePilotHistory(String householdId, PilotHistory history) async {
    _reports.addAll(history.reports);
    _posts.addAll(history.posts);
    _readings.putIfAbsent(householdId, () => []).addAll(history.readings);
    _topups.putIfAbsent(householdId, () => []).addAll(history.topups);
    for (final p in history.predictions) {
      await savePrediction(householdId, p);
    }
    _notify();
  }
}
