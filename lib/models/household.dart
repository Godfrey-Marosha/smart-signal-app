/// One household's profile, captured once after sign-in.
/// Firestore: households/{uid}
class Household {
  Household({
    required this.id,
    required this.ownerUid,
    required this.displayName,
    required this.areaId,
    required this.areaName,
    this.ward = '',
    this.people = 1,
    this.prepaid = true,
    this.storageLitres = 0,
    this.electricityBudgetCents = 0,
    this.consent = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String ownerUid;
  final String displayName;
  final String areaId;
  final String areaName;
  final String ward;
  final int people;
  final bool prepaid;
  final int storageLitres;
  final int electricityBudgetCents;
  final bool consent;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'displayName': displayName,
        'areaId': areaId,
        'areaName': areaName,
        'ward': ward,
        'people': people,
        'electricity': {'billing': prepaid ? 'prepaid' : 'postpaid'},
        'water': {'storageLitres': storageLitres},
        'budgets': {'electricityCents': electricityBudgetCents},
        'consent': {'data': consent},
        'createdAt': createdAt,
      };

  factory Household.fromMap(String id, Map<String, dynamic> m) {
    Map<String, dynamic> sub(String k) => Map<String, dynamic>.from((m[k] as Map?) ?? const {});
    return Household(
      id: id,
      ownerUid: m['ownerUid'] as String? ?? '',
      displayName: m['displayName'] as String? ?? '',
      areaId: m['areaId'] as String? ?? '',
      areaName: m['areaName'] as String? ?? '',
      ward: m['ward'] as String? ?? '',
      people: (m['people'] as num?)?.toInt() ?? 1,
      prepaid: sub('electricity')['billing'] != 'postpaid',
      storageLitres: (sub('water')['storageLitres'] as num?)?.toInt() ?? 0,
      electricityBudgetCents: (sub('budgets')['electricityCents'] as num?)?.toInt() ?? 0,
      consent: sub('consent')['data'] == true,
      createdAt: m['createdAt'] is DateTime ? m['createdAt'] as DateTime : null,
    );
  }

  /// A ready-made household for demos and judging.
  factory Household.demo({required String uid, String name = 'Thandi'}) => Household(
        id: uid,
        ownerUid: uid,
        displayName: name,
        areaId: 'demo-township',
        areaName: 'Demo Township',
        ward: 'Ward 12',
        people: 4,
        prepaid: true,
        storageLitres: 60,
        electricityBudgetCents: 80000,
        consent: true,
      );
}
