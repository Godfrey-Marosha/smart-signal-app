import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../logic/pilot_history.dart';
import '../models/community.dart';
import '../models/household.dart';
import '../models/records.dart';
import 'repository.dart';

/// Live backend shared with the .NET dashboard. Collection and field names
/// follow the system spec's data model.
class FirestoreRepository implements Repository {
  FirestoreRepository(this.uid, {FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  @override
  final String uid;
  final FirebaseFirestore _db;

  @override
  bool get isDemo => false;

  /// The household's area, stamped on every household sub-record so the
  /// dashboard can query top-ups, readings and forecasts per area
  /// (collection-group queries).
  String? _areaId;

  Map<String, dynamic> _stamped(Map<String, dynamic> data) => {...data, 'areaId': _areaId, 'householdId': uid};

  @override
  String newId() => _db.collection('_ids').doc().id;

  CollectionReference<Map<String, dynamic>> get _households => _db.collection('households');
  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');
  CollectionReference<Map<String, dynamic>> get _alerts => _db.collection('alerts');
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  /// Firestore returns Timestamps; the models expect DateTime.
  static Map<String, dynamic> _plain(Map<String, dynamic> m) => m.map((k, v) => MapEntry(k, _plainValue(v)));

  static Object? _plainValue(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is Map) return _plain(Map<String, dynamic>.from(v));
    if (v is List) return v.map(_plainValue).toList();
    return v;
  }

  @override
  Future<Household?> loadHousehold() async {
    final doc = _households.doc(uid);
    DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await doc.get().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Slow or no network: use the copy on the phone if there is one.
      snap = await doc.get(const GetOptions(source: Source.cache));
    }
    final data = snap.data();
    final h = data == null ? null : Household.fromMap(snap.id, _plain(data));
    _areaId = h?.areaId;
    return h;
  }

  @override
  Future<void> saveHousehold(Household household) async {
    _areaId = household.areaId;
    await _households.doc(household.id).set(
      {...household.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    // Helper documents for the dashboard. They must never block or break
    // onboarding, so they are sent in the background.
    void background(Future<void> write, String what) =>
        unawaited(write.catchError((Object e) => debugPrint('Street Signal: $what write failed: $e')));
    background(
      _db.collection('areas').doc(household.areaId).set({
        'name': household.areaName,
        'ward': household.ward,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'areas',
    );
    background(
      _db.collection('users').doc(uid).set({
        'displayName': household.displayName,
        'householdId': household.id,
        'role': 'resident',
        'consent': {'data': household.consent, 'acceptedAt': FieldValue.serverTimestamp()},
      }, SetOptions(merge: true)),
      'users',
    );
  }

  @override
  Stream<List<ServiceReport>> watchAreaReports(String areaId) {
    // Single-field query (no composite index needed); filter and sort here.
    return _reports.where('areaId', isEqualTo: areaId).snapshots().map((q) {
      final cutoff = DateTime.now().subtract(const Duration(days: 56));
      final list = q.docs
          .map((d) => ServiceReport.fromMap(d.id, _plain(d.data())))
          .where((r) => r.startedAt.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    });
  }

  @override
  Future<void> addReport(ServiceReport report) =>
      _reports.doc(report.id).set({...report.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  @override
  Future<void> markRestored(ServiceReport report, DateTime at) =>
      _reports.doc(report.id).update(ServiceReport.restoredFields(report.startedAt, at));

  @override
  Stream<List<AlertItem>> watchAlerts(String areaId) {
    return _alerts.where('areaIds', arrayContains: areaId).snapshots().map((q) {
      final list = q.docs.map((d) => AlertItem.fromMap(d.id, _plain(d.data()))).toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return list.take(20).toList();
    });
  }

  @override
  Future<List<Topup>> loadTopups(String householdId) async {
    final q = await _households.doc(householdId).collection('topups').get();
    return q.docs.map((d) => Topup.fromMap(d.id, _plain(d.data()))).toList();
  }

  @override
  Future<void> addTopup(String householdId, Topup topup) =>
      _households.doc(householdId).collection('topups').doc(topup.id).set(_stamped(topup.toMap()));

  @override
  Future<List<Reading>> loadReadings(String householdId) async {
    final q = await _households.doc(householdId).collection('readings').get();
    return q.docs.map((d) => Reading.fromMap(d.id, _plain(d.data()))).toList();
  }

  @override
  Future<void> addReading(String householdId, Reading reading) =>
      _households.doc(householdId).collection('readings').doc(reading.id).set(_stamped(reading.toMap()));

  @override
  Future<List<Prediction>> loadPredictions(String householdId) async {
    final q = await _households.doc(householdId).collection('predictions').get();
    return q.docs.map((d) => Prediction.fromMap(d.id, _plain(d.data()))).toList();
  }

  @override
  Future<void> savePrediction(String householdId, Prediction prediction) =>
      _households.doc(householdId).collection('predictions').doc(prediction.id).set(_stamped(prediction.toMap()));

  @override
  Stream<List<CommunityPost>> watchPosts(String areaId) {
    return _posts.where('areaId', isEqualTo: areaId).snapshots().map((q) {
      final list = q.docs.map((d) => CommunityPost.fromMap(d.id, _plain(d.data()))).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<void> addPost(CommunityPost post) =>
      _posts.doc(post.id).set({...post.toMap(), 'serverCreatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> setMember(CommunityPost post, bool join) => _posts.doc(post.id).update({
        'members': join ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  @override
  Future<void> closePost(CommunityPost post) => _posts.doc(post.id).update({'open': false});

  @override
  Future<List<HouseholdNeed>> loadNeeds(String householdId) async {
    final q = await _households.doc(householdId).collection('needs').get();
    return q.docs.map((d) => HouseholdNeed.fromMap(d.id, _plain(d.data()))).toList();
  }

  @override
  Future<void> addNeed(String householdId, HouseholdNeed need) =>
      _households.doc(householdId).collection('needs').doc(need.id).set(_stamped(need.toMap()));

  @override
  Future<void> removeNeed(String householdId, String needId) =>
      _households.doc(householdId).collection('needs').doc(needId).delete();

  @override
  Future<void> savePilotHistory(String householdId, PilotHistory history) async {
    final home = _households.doc(householdId);
    final writes = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[
      for (final r in history.reports) (_reports.doc(r.id), {...r.toMap(), 'createdAt': FieldValue.serverTimestamp()}),
      for (final r in history.readings) (home.collection('readings').doc(r.id), _stamped(r.toMap())),
      for (final t in history.topups) (home.collection('topups').doc(t.id), _stamped(t.toMap())),
      for (final p in history.predictions) (home.collection('predictions').doc(p.id), _stamped(p.toMap())),
      for (final p in history.posts) (_posts.doc(p.id), {...p.toMap(), 'serverCreatedAt': FieldValue.serverTimestamp()}),
    ];
    // Firestore allows up to 500 writes per batch.
    for (var i = 0; i < writes.length; i += 400) {
      final batch = _db.batch();
      for (final (ref, data) in writes.skip(i).take(400)) {
        batch.set(ref, data);
      }
      await batch.commit();
    }
  }
}
