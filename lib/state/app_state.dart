import 'dart:async';

import 'package:flutter/widgets.dart';

import '../auth/auth_service.dart';
import '../core/enums.dart';
import '../data/repository.dart';
import '../logic/pilot_history.dart';
import '../logic/prediction_engine.dart';
import '../models/community.dart';
import '../models/household.dart';
import '../models/records.dart';

/// App-wide state. Screens read it with `AppScope.of(context)`.
/// Flow: signed out -> sign in -> onboarding (once) -> main app.
class AppState extends ChangeNotifier {
  AppState({
    required this.auth,
    required this.repositoryFor,
    DateTime Function()? clock,
    this.engine = const PredictionEngine(),
  }) : _clock = clock ?? DateTime.now;

  final AuthService auth;

  /// Creates the data source for a signed-in user.
  final Repository Function(AppUser user) repositoryFor;
  final PredictionEngine engine;
  final DateTime Function() _clock;

  DateTime get now => _clock();

  bool ready = false;
  AppUser? user;
  Repository? _repo;
  Household? household;

  List<ServiceReport> reports = const [];
  List<AlertItem> alerts = const [];
  List<Topup> topups = const [];
  List<Reading> readings = const [];
  List<Prediction> history = const [];
  List<CommunityPost> posts = const [];
  List<HouseholdNeed> needs = const [];

  // Derived after every change.
  List<Prediction> predictions = const [];
  ElectricityForecast? electricity;
  BudgetForecast? budget;
  List<DailyUsage> usage = const [];
  HouseholdImpact? impact;
  AreaSummary? area;
  OutageWindow? nextPowerCut;

  /// Set when the household's data could not be loaded (e.g. offline).
  String? loadError;

  Timer? _recomputeTimer;
  int _userSeq = 0;

  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<AppUser?>? _authSub;

  Repository get repo => _repo!;
  bool get isDemo => auth.isDemo;

  // ------------------------------------------------------------------- lifecycle

  static const _loadTimeout = Duration(seconds: 10);

  Future<void> init() async {
    final first = Completer<void>();
    _authSub = auth.userChanges.listen((u) async {
      try {
        await _onUser(u);
      } catch (e) {
        debugPrint('Street Signal: could not load account: $e');
      } finally {
        if (!first.isCompleted) first.complete();
      }
    });
    // Never keep the splash screen up forever.
    await first.future.timeout(const Duration(seconds: 15), onTimeout: () {});
    ready = true;
    notifyListeners();
  }

  Future<void> _onUser(AppUser? u) async {
    if (u?.uid == user?.uid && _repo != null) return;
    final seq = ++_userSeq;
    await _detach();
    user = u;
    household = null;
    loadError = null;
    _repo = u == null ? null : repositoryFor(u);
    if (_repo != null) {
      try {
        final h = await repo.loadHousehold().timeout(_loadTimeout);
        if (seq != _userSeq) return; // a newer sign-in/out happened meanwhile
        household = h;
      } catch (e) {
        debugPrint('Street Signal: loadHousehold failed: $e');
        loadError = 'Could not reach the server. Check your internet connection.';
      }
      if (household != null) _attach();
    }
    if (seq == _userSeq) notifyListeners();
  }

  Future<void> _detach() async {
    _recomputeTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    reports = const [];
    alerts = const [];
    topups = const [];
    readings = const [];
    history = const [];
    posts = const [];
    needs = const [];
    predictions = const [];
    electricity = null;
    budget = null;
    usage = const [];
    impact = null;
    area = null;
    nextPowerCut = null;
  }

  /// Starts live listeners straight away and loads the household's own
  /// records in parallel. The UI shows immediately and fills in as data
  /// arrives, instead of waiting on four sequential round trips.
  void _attach() {
    final h = household!;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    void onError(Object e) => debugPrint('Street Signal: stream error: $e');
    _subs.add(repo.watchPosts(h.areaId).listen((v) {
      posts = v;
      notifyListeners();
    }, onError: onError));
    _subs.add(repo.watchAreaReports(h.areaId).listen((v) {
      reports = v;
      _scheduleRecompute();
    }, onError: onError));
    _subs.add(repo.watchAlerts(h.areaId).listen((v) {
      alerts = v;
      notifyListeners(); // alerts don't change any forecast
    }, onError: onError));
    _recompute();
    unawaited(_loadPrivate(h));
  }

  Future<void> _loadPrivate(Household h) async {
    Future<List<T>> safe<T>(Future<List<T>> f) =>
        f.timeout(_loadTimeout).catchError((Object e) {
          debugPrint('Street Signal: load failed: $e');
          return <T>[];
        });
    final results = await Future.wait<List<Object>>([
      safe(repo.loadTopups(h.id)),
      safe(repo.loadReadings(h.id)),
      safe(repo.loadPredictions(h.id)),
      safe(repo.loadNeeds(h.id)),
    ]);
    if (household?.id != h.id) return;
    topups = results[0].cast<Topup>();
    readings = results[1].cast<Reading>();
    history = results[2].cast<Prediction>();
    needs = results[3].cast<HouseholdNeed>();
    _changed();
  }

  @override
  void dispose() {
    _recomputeTimer?.cancel();
    _authSub?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _changed() {
    _recomputeTimer?.cancel();
    _recompute();
    notifyListeners();
  }

  /// Live snapshots often arrive in bursts (cache, then server; or hundreds
  /// of pilot reports). Recompute forecasts once per burst, not per event.
  void _scheduleRecompute() {
    _recomputeTimer?.cancel();
    _recomputeTimer = Timer(const Duration(milliseconds: 120), _changed);
  }

  void _recompute() {
    final h = household;
    if (h == null) return;
    final t = now;
    predictions = engine.homePredictions(household: h, reports: reports, readings: readings, topups: topups, now: t);
    electricity = h.prepaid ? engine.electricity(readings, topups, t) : null;
    budget = h.prepaid ? engine.electricityBudget(h.electricityBudgetCents, topups, electricity, t) : null;
    usage = h.prepaid ? engine.dailyUsage(readings, topups, t) : const [];

    // Remember outage forecasts (with when we warned) so we can ask
    // "Did this happen?" afterwards and count the impact.
    final known = history.map((p) => p.id).toSet();
    final fresh = predictions.where((p) => p.isCheckable && !known.contains(p.id)).map((p) => p.copyWith(issuedAt: t)).toList();
    if (fresh.isNotEmpty) {
      history = [...history, ...fresh];
      for (final p in fresh) {
        unawaited(repo.savePrediction(h.id, p).catchError((Object e) => debugPrint('Street Signal: savePrediction failed: $e')));
      }
    }

    impact = engine.householdImpact(
      history: history,
      readings: readings,
      topups: topups,
      storageLitres: h.storageLitres,
      people: h.people,
      now: t,
    );
    area = engine.areaSummary(reports, t);
    final cuts = engine.outageWindows(reports, Service.electricity, t);
    nextPowerCut = cuts.isEmpty ? null : cuts.first;
  }

  // --------------------------------------------------------------------- account

  Future<void> signOut() => auth.signOut();

  /// Saves the household and opens the app straight away.
  ///
  /// Firestore applies the write locally at once but only completes the
  /// future when the server confirms it. We wait a few seconds so real
  /// problems (rules not deployed, database not created) show as an error;
  /// if the network is just slow, the write stays queued and we carry on.
  Future<void> saveHousehold(Household h) async {
    try {
      await repo.saveHousehold(h).timeout(const Duration(seconds: 6));
    } on TimeoutException {
      debugPrint('Street Signal: saveHousehold still pending; continuing offline.');
    }
    final sameArea = household?.areaId == h.areaId;
    household = h;
    loadError = null;
    if (sameArea && _subs.isNotEmpty) {
      _changed();
    } else {
      _attach();
      notifyListeners();
    }
  }

  /// Try loading the account again after a failed start (e.g. offline).
  Future<void> retryLoad() async {
    final u = user;
    _repo = null;
    user = null;
    await _onUser(u);
  }

  /// Live mode: loads the small pilot history for this area (water and power
  /// outages for 4 weeks, plus 10 days of this home's meter readings).
  Future<void> loadPilotHistory() async {
    final h = household!;
    final pilot = PilotHistory.generate(
      areaId: h.areaId,
      areaName: h.areaName,
      ward: h.ward,
      uid: repo.uid,
      now: now,
      newId: repo.newId,
      people: h.people,
      storageLitres: h.storageLitres,
      prepaid: h.prepaid,
    );
    await repo.savePilotHistory(h.id, pilot);
    // We just wrote these, so use them directly instead of reading them back.
    topups = [...topups, ...pilot.topups];
    readings = [...readings, ...pilot.readings];
    history = [...history.where((p) => !pilot.predictions.any((x) => x.id == p.id)), ...pilot.predictions];
    _changed();
  }

  bool get hasPilotHistory => reports.any((r) => r.pilot) || posts.any((p) => p.pilot);

  // ------------------------------------------------------------------ community

  List<CommunityPost> activePosts(Sector sector) =>
      posts.where((p) => p.sector == sector && p.isActive(now)).toList();

  int activeCount(Sector sector) => activePosts(sector).length;

  bool isMine(CommunityPost p) => _repo != null && p.uid == _repo!.uid && !p.pilot;

  bool hasJoined(CommunityPost p) => _repo != null && p.members.contains(_repo!.uid);

  Future<void> addPost({
    required PostTopic topic,
    required String title,
    String details = '',
    String place = '',
    String contact = '',
    WaterQuality? quality,
    int? target,
    Duration? lasts,
  }) async {
    final h = household!;
    await repo.addPost(CommunityPost(
      id: repo.newId(),
      uid: repo.uid,
      displayName: h.displayName,
      areaId: h.areaId,
      areaName: h.areaName,
      ward: h.ward,
      topic: topic,
      title: title.trim(),
      details: details.trim(),
      place: place.trim(),
      contact: contact.trim(),
      quality: quality,
      target: target,
      createdAt: now,
      expiresAt: lasts == null ? null : now.add(lasts),
    ));
  }

  Future<void> toggleJoin(CommunityPost p) => repo.setMember(p, !hasJoined(p));

  Future<void> closePost(CommunityPost p) => repo.closePost(p);

  /// The latest water-quality check in the area, and how many in the last
  /// 7 days were not clear.
  ({CommunityPost? latest, int problems}) get waterQuality {
    final checks = posts.where((p) => p.topic.id == 'water_quality' && now.difference(p.createdAt).inDays < 7).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (
      latest: checks.isEmpty ? null : checks.first,
      problems: checks.where((p) => p.quality != null && p.quality != WaterQuality.clear).length,
    );
  }

  /// When to run heavy appliances: outside Eskom's peak hours and away from
  /// the next predicted power cut in this area.
  ({String best, String avoid, OutageWindow? nextCut}) get energyTiming => (
        best: '10:00 to 16:00, or after 21:00',
        avoid: '06:00 to 09:00 and 17:00 to 21:00 (peak hours)',
        nextCut: nextPowerCut, // worked out once in _recompute, not on every build
      );

  // ---------------------------------------------------------- emergency needs

  Future<void> addNeed(NeedKind kind, {String note = ''}) async {
    final h = household!;
    final n = HouseholdNeed(id: repo.newId(), kind: kind, note: note.trim(), createdAt: now);
    await repo.addNeed(h.id, n);
    needs = [...needs, n];
    notifyListeners();
  }

  Future<void> removeNeed(HouseholdNeed n) async {
    await repo.removeNeed(household!.id, n.id);
    needs = needs.where((x) => x.id != n.id).toList();
    notifyListeners();
  }

  // -------------------------------------------------------------------- reports

  Future<void> submitReport(Service service, ReportStatus status, {String note = ''}) async {
    final h = household!;
    final backOn = status == ReportStatus.backOn;
    await repo.addReport(ServiceReport(
      id: repo.newId(),
      uid: repo.uid,
      areaId: h.areaId,
      areaName: h.areaName,
      ward: h.ward,
      people: h.people,
      service: service,
      status: status,
      startedAt: now,
      restoredAt: backOn ? now : null,
      note: note.trim(),
    ));
    if (backOn) {
      for (final r in myOpenReports.where((r) => r.service == service)) {
        await repo.markRestored(r, now);
      }
    }
  }

  Future<void> markBackOn(ServiceReport report) => repo.markRestored(report, now);

  List<ServiceReport> get myOpenReports {
    final uid = _repo?.uid;
    if (uid == null) return const [];
    return reports.where((r) => r.uid == uid && r.isOpen && !r.pilot).toList();
  }

  /// Open problems reported in the last 12 hours, grouped by service.
  Map<Service, List<ServiceReport>> get openByService {
    final cutoff = now.subtract(const Duration(hours: 12));
    final out = <Service, List<ServiceReport>>{};
    for (final r in reports.where((r) => r.isOpen && r.startedAt.isAfter(cutoff))) {
      out.putIfAbsent(r.service, () => []).add(r);
    }
    return out;
  }

  // ---------------------------------------------------------------- electricity

  Future<void> addTopup(double randsPaid, double units) async {
    final h = household!;
    final t = Topup(id: repo.newId(), date: now, amountCents: (randsPaid * 100).round(), units: units);
    await repo.addTopup(h.id, t);
    topups = [...topups, t];
    _changed();
  }

  Future<void> addUnitsLeft(double units) async {
    final h = household!;
    final r = Reading(id: repo.newId(), kind: ReadingKind.elecUnits, value: units, at: now);
    await repo.addReading(h.id, r);
    readings = [...readings, r];
    _changed();
  }

  // -------------------------------------------------------------------- feedback

  List<Prediction> get pendingFeedback {
    final t = now;
    return history
        .where((p) => p.isCheckable && p.feedback == null && p.to != null && p.to!.isBefore(t) && t.difference(p.to!).inDays < 7)
        .toList()
      ..sort((a, b) => b.from.compareTo(a.from));
  }

  Future<void> answer(Prediction p, String answer) async {
    final h = household!;
    final current = history.firstWhere((x) => x.id == p.id, orElse: () => p);
    final updated = current.copyWith(feedback: answer);
    _upsert(updated);
    await repo.savePrediction(h.id, updated);
    _changed();
  }

  /// The resident did the suggested action ("Done" on a forecast card).
  Future<void> markDone(Prediction p) async {
    final h = household!;
    final current = history.firstWhere((x) => x.id == p.id, orElse: () => p.copyWith(issuedAt: now));
    final updated = current.copyWith(acted: true);
    _upsert(updated);
    await repo.savePrediction(h.id, updated);
    _changed();
  }

  bool isDone(Prediction p) => history.any((x) => x.id == p.id && x.acted);

  void _upsert(Prediction p) {
    history = [...history.where((x) => x.id != p.id), p];
  }

  double? get accuracy {
    final answered = history.where((p) => p.feedback != null).toList();
    if (answered.isEmpty) return null;
    final score = answered.fold(0.0, (s, p) => s + (p.feedback == 'yes' ? 1.0 : p.feedback == 'partly' ? 0.5 : 0.0));
    return score / answered.length;
  }

  int get answeredCount => history.where((p) => p.feedback != null).length;
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }
}
