import '../logic/pilot_history.dart';
import '../models/community.dart';
import '../models/household.dart';
import '../models/records.dart';

/// Everything the app reads and writes for one signed-in user.
///  * [DemoRepository]: in memory, works offline (demo mode and tests).
///  * [FirestoreRepository]: the live backend shared with the .NET dashboard.
abstract class Repository {
  String get uid;
  bool get isDemo;

  Future<Household?> loadHousehold();
  Future<void> saveHousehold(Household household);

  Stream<List<ServiceReport>> watchAreaReports(String areaId);
  Future<void> addReport(ServiceReport report);
  /// Marks a report "back on" and records how long the outage lasted.
  Future<void> markRestored(ServiceReport report, DateTime at);

  Stream<List<AlertItem>> watchAlerts(String areaId);

  Future<List<Topup>> loadTopups(String householdId);
  Future<void> addTopup(String householdId, Topup topup);

  Future<List<Reading>> loadReadings(String householdId);
  Future<void> addReading(String householdId, Reading reading);

  Future<List<Prediction>> loadPredictions(String householdId);
  Future<void> savePrediction(String householdId, Prediction prediction);

  // Community
  Stream<List<CommunityPost>> watchPosts(String areaId);
  Future<void> addPost(CommunityPost post);

  /// Adds or removes the signed-in user from a post's `members`.
  Future<void> setMember(CommunityPost post, bool join);
  Future<void> closePost(CommunityPost post);

  // Private emergency needs (households/{uid}/needs)
  Future<List<HouseholdNeed>> loadNeeds(String householdId);
  Future<void> addNeed(String householdId, HouseholdNeed need);
  Future<void> removeNeed(String householdId, String needId);

  /// Writes pilot history in one go.
  Future<void> savePilotHistory(String householdId, PilotHistory history);

  String newId();
}
