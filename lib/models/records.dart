import '../core/enums.dart';

DateTime _date(Object? v) {
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

/// A resident's report of a water or power problem. Firestore: reports/{id}
///
/// Besides what the resident entered, each report carries denormalised fields
/// so the .NET dashboard can chart it without extra lookups: area name and
/// ward, people affected, duration, and day / weekday / hour buckets.
class ServiceReport {
  ServiceReport({
    required this.id,
    required this.uid,
    required this.areaId,
    required this.service,
    required this.status,
    required this.startedAt,
    this.areaName = '',
    this.ward = '',
    this.people = 1,
    this.restoredAt,
    this.note = '',
    this.pilot = false,
    this.pilotHousehold,
  });

  final String id;
  final String uid;
  final String areaId;
  final String areaName;
  final String ward;

  /// People living in the reporting household ("people affected").
  final int people;
  final Service service;
  final ReportStatus status;
  final DateTime startedAt;
  final DateTime? restoredAt;
  final String note;

  /// True for loaded pilot history (so it can be told apart and removed later).
  final bool pilot;

  /// Which simulated pilot household made the report (pilot data only).
  /// Real reports are always written with the reporter's own uid.
  final String? pilotHousehold;

  /// Who reported it, for counting distinct households.
  String get reporter => pilotHousehold ?? uid;

  bool get isOpen => restoredAt == null && status.isDisruption;

  int? get durationMinutes => restoredAt?.difference(startedAt).inMinutes;

  ServiceReport copyWith({DateTime? restoredAt}) => ServiceReport(
        id: id,
        uid: uid,
        areaId: areaId,
        areaName: areaName,
        ward: ward,
        people: people,
        service: service,
        status: status,
        startedAt: startedAt,
        restoredAt: restoredAt ?? this.restoredAt,
        note: note,
        pilot: pilot,
        pilotHousehold: pilotHousehold,
      );

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        // Who and where
        'uid': uid,
        'householdId': pilotHousehold ?? uid,
        'areaId': areaId,
        'areaName': areaName,
        'ward': ward,
        'people': people,
        // What
        'service': service.wire,
        'status': status.wire,
        'note': note,
        // When (plus buckets for charts: per day, per weekday, per hour)
        'startedAt': startedAt,
        'restoredAt': restoredAt,
        'durationMinutes': durationMinutes,
        'day': _day(startedAt),
        'weekday': startedAt.weekday, // 1 = Monday ... 7 = Sunday
        'hour': startedAt.hour,
        // Data quality
        'source': pilot ? 'pilot' : 'app',
        'pilot': pilot,
        if (pilotHousehold != null) 'pilotHousehold': pilotHousehold,
      };

  /// Fields to write when a report is marked "back on".
  static Map<String, dynamic> restoredFields(DateTime startedAt, DateTime restoredAt) => {
        'restoredAt': restoredAt,
        'durationMinutes': restoredAt.difference(startedAt).inMinutes,
      };

  factory ServiceReport.fromMap(String id, Map<String, dynamic> m) => ServiceReport(
        id: id,
        uid: m['uid'] as String? ?? '',
        areaId: m['areaId'] as String? ?? '',
        areaName: m['areaName'] as String? ?? '',
        ward: m['ward'] as String? ?? '',
        people: (m['people'] as num?)?.toInt() ?? 1,
        service: Service.fromWire(m['service'] as String?),
        status: ReportStatus.fromWire(m['status'] as String?),
        startedAt: _date(m['startedAt']),
        restoredAt: _dateOrNull(m['restoredAt']),
        note: m['note'] as String? ?? '',
        pilot: m['pilot'] == true,
        pilotHousehold: m['pilotHousehold'] as String?,
      );
}

/// Prepaid electricity purchase. Firestore: households/{id}/topups/{id}
class Topup {
  Topup({required this.id, required this.date, required this.amountCents, required this.units});

  final String id;
  final DateTime date;
  final int amountCents;
  final double units;

  Map<String, dynamic> toMap() => {'date': date, 'amountCents': amountCents, 'units': units};

  factory Topup.fromMap(String id, Map<String, dynamic> m) => Topup(
        id: id,
        date: _date(m['date']),
        amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
        units: (m['units'] as num?)?.toDouble() ?? 0,
      );
}

/// A meter reading. Firestore: households/{id}/readings/{id}
class Reading {
  Reading({required this.id, required this.kind, required this.value, required this.at});

  final String id;
  final ReadingKind kind;
  final double value;
  final DateTime at;

  Map<String, dynamic> toMap() => {'kind': kind.wire, 'value': value, 'at': at};

  factory Reading.fromMap(String id, Map<String, dynamic> m) => Reading(
        id: id,
        kind: ReadingKind.fromWire(m['kind'] as String?),
        value: (m['value'] as num?)?.toDouble() ?? 0,
        at: _date(m['at']),
      );
}

/// An alert sent to an area from the ward dashboard. Firestore: alerts/{id}
class AlertItem {
  AlertItem({
    required this.id,
    required this.areaIds,
    required this.service,
    required this.title,
    required this.body,
    required this.source,
    required this.sentAt,
  });

  final String id;
  final List<String> areaIds;
  final Service service;
  final String title;
  final String body;
  final AlertSource source;
  final DateTime sentAt;

  factory AlertItem.fromMap(String id, Map<String, dynamic> m) {
    final body = m['body'];
    final text = body is Map ? (body['en'] ?? '').toString() : (body?.toString() ?? '');
    return AlertItem(
      id: id,
      areaIds: List<String>.from((m['areaIds'] as List?) ?? const []),
      service: Service.fromWire(m['service'] as String?),
      title: m['title'] as String? ?? '',
      body: text,
      source: AlertSource.fromWire(m['source'] as String?),
      sentAt: _date(m['sentAt']),
    );
  }
}

/// A forecast shown to the household. Firestore: households/{id}/predictions/{id}
class Prediction {
  Prediction({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.from,
    this.to,
    this.service,
    this.action = '',
    this.probability,
    this.feedback,
    this.issuedAt,
    this.acted = false,
  });

  final String id;
  final PredictionType type;
  final Service? service;
  final String title;
  final String detail;
  final String action;
  final double? probability;
  final DateTime from;
  final DateTime? to;

  /// 'yes' | 'no' | 'partly' once the resident has answered "Did this happen?"
  final String? feedback;

  /// When the household was first warned.
  final DateTime? issuedAt;

  /// True once the resident tapped "Done" on the suggested action.
  final bool acted;

  bool get cameTrue => feedback == 'yes' || feedback == 'partly';

  bool get isCheckable => type == PredictionType.waterOutage || type == PredictionType.powerOutage;

  Prediction copyWith({String? feedback, bool? acted, DateTime? issuedAt}) => Prediction(
        id: id,
        type: type,
        service: service,
        title: title,
        detail: detail,
        action: action,
        probability: probability,
        from: from,
        to: to,
        feedback: feedback ?? this.feedback,
        issuedAt: issuedAt ?? this.issuedAt,
        acted: acted ?? this.acted,
      );

  Map<String, dynamic> toMap() => {
        'type': type.wire,
        'service': service?.wire,
        'title': title,
        'message': detail,
        'action': action,
        'probability': probability,
        'forDate': from,
        'toDate': to,
        'feedback': feedback,
        'issuedAt': issuedAt,
        'acted': acted,
      };

  factory Prediction.fromMap(String id, Map<String, dynamic> m) => Prediction(
        id: id,
        type: PredictionType.fromWire(m['type'] as String?),
        service: m['service'] == null ? null : Service.fromWire(m['service'] as String?),
        title: m['title'] as String? ?? '',
        detail: m['message'] as String? ?? '',
        action: m['action'] as String? ?? '',
        probability: (m['probability'] as num?)?.toDouble(),
        from: _date(m['forDate']),
        to: _dateOrNull(m['toDate']),
        feedback: m['feedback'] as String?,
        issuedAt: _dateOrNull(m['issuedAt']),
        acted: m['acted'] == true,
      );
}
