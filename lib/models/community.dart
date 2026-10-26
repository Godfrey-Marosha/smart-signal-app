import 'package:flutter/material.dart';

DateTime _date(Object? v) {
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

T _fromWire<T>(List<T> values, String? wire, String Function(T) getWire, T fallback) {
  for (final v in values) {
    if (getWire(v) == wire) return v;
  }
  return fallback;
}

/// The five areas of community resilience covered by the Community tab.
enum Sector {
  food('food', 'Food', Icons.restaurant_outlined, Color(0xFF2E7D32), 'Share food, buy together, save money'),
  energy('energy', 'Energy', Icons.bolt_outlined, Color(0xFFF2A541), 'Use power at the right time, share charging'),
  water('water', 'Water', Icons.water_drop_outlined, Color(0xFF1565C0), 'Check water quality, find working taps'),
  transport('transport', 'Transport', Icons.directions_car_outlined, Color(0xFF6A1B9A), 'Share lifts and things you own'),
  prepare('prepare', 'Prepare', Icons.health_and_safety_outlined, Color(0xFFC0392B), 'Help each other when things go wrong');

  const Sector(this.wire, this.label, this.icon, this.color, this.tagline);
  final String wire;
  final String label;
  final IconData icon;
  final Color color;
  final String tagline;

  static Sector fromWire(String? v) => _fromWire(values, v, (e) => e.wire, food);
}

/// How people respond to a post.
enum PostKind {
  place('place'), // somewhere useful: a garden, pantry, water point, charging spot
  offer('offer'), // something on offer: surplus food, a lift, an item to lend, help
  request('request'), // something needed
  group('group'), // a group buy that fills up
  check('check'); // a quick check-in, e.g. water quality or a blocked road

  const PostKind(this.wire);
  final String wire;
  static PostKind fromWire(String? v) => _fromWire(values, v, (e) => e.wire, offer);
}

/// Water quality as residents see and smell it, or from a test kit.
enum WaterQuality {
  clear('clear', 'Clear', Color(0xFF2E7D32)),
  cloudy('cloudy', 'Cloudy or brown', Color(0xFFF2A541)),
  smell('smell', 'Smells or tastes bad', Color(0xFFF2A541)),
  unsafe('unsafe', 'Test kit says unsafe', Color(0xFFC0392B));

  const WaterQuality(this.wire, this.label, this.color);
  final String wire;
  final String label;
  final Color color;
  static WaterQuality? fromWireOrNull(String? v) => v == null ? null : _fromWire<WaterQuality>(values, v, (e) => e.wire, clear);
}

/// The things you can post, per sector. `id` is stored as the post's `topic`.
class PostTopic {
  const PostTopic({
    required this.id,
    required this.sector,
    required this.kind,
    required this.label,
    required this.icon,
    required this.titleHint,
    this.detailsHint = '',
    this.action = 'I\'m interested',
    this.hasPlace = true,
    this.hasTarget = false,
    this.hasQuality = false,
  });

  final String id;
  final Sector sector;
  final PostKind kind;
  final String label;
  final IconData icon;
  final String titleHint;
  final String detailsHint;

  /// The button neighbours tap to respond.
  final String action;
  final bool hasPlace;

  /// Group buys: how many households it needs.
  final bool hasTarget;

  /// Water checks: pick a quality level.
  final bool hasQuality;

  static PostTopic byId(String? id) => all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static List<PostTopic> forSector(Sector s) => all.where((t) => t.sector == s).toList();

  static const all = <PostTopic>[
    // Food
    PostTopic(id: 'food_place', sector: Sector.food, kind: PostKind.place, label: 'Garden or food pantry', icon: Icons.yard_outlined,
        titleHint: 'e.g. Community garden behind the clinic', detailsHint: 'When it is open, what is available', action: 'I\'ll visit'),
    PostTopic(id: 'food_group', sector: Sector.food, kind: PostKind.group, label: 'Bulk-buy group', icon: Icons.groups_outlined,
        titleHint: 'e.g. Maize meal 50 kg, split 5 ways', detailsHint: 'Price per household, where to collect', action: 'Join group', hasTarget: true),
    PostTopic(id: 'food_surplus', sector: Sector.food, kind: PostKind.offer, label: 'Surplus food', icon: Icons.shopping_basket_outlined,
        titleHint: 'e.g. 20 loaves from the bakery, free after 17:00', detailsHint: 'What, how much, until when', action: 'I\'ll collect'),
    // Energy
    PostTopic(id: 'energy_charging', sector: Sector.energy, kind: PostKind.place, label: 'Charging spot', icon: Icons.battery_charging_full_outlined,
        titleHint: 'e.g. Solar charging at the spaza', detailsHint: 'When it is available, any cost', action: 'I\'ll use it'),
    PostTopic(id: 'energy_group', sector: Sector.energy, kind: PostKind.group, label: 'Buy solar or gas together', icon: Icons.solar_power_outlined,
        titleHint: 'e.g. 9 kg gas refills, bulk price', detailsHint: 'Price per household, supplier', action: 'Join group', hasTarget: true),
    // Water
    PostTopic(id: 'water_quality', sector: Sector.water, kind: PostKind.check, label: 'Water quality check', icon: Icons.science_outlined,
        titleHint: 'e.g. Tap water on 5th Street', detailsHint: 'What you noticed, or the test result', action: 'Same here', hasQuality: true),
    PostTopic(id: 'water_point', sector: Sector.water, kind: PostKind.place, label: 'Working water point or tanker', icon: Icons.water_outlined,
        titleHint: 'e.g. Tanker at the school gate until 14:00', detailsHint: 'Where and until when', action: 'Thanks, going'),
    PostTopic(id: 'water_share', sector: Sector.water, kind: PostKind.offer, label: 'Spare stored water', icon: Icons.propane_tank_outlined,
        titleHint: 'e.g. 200 L in my JoJo tank', detailsHint: 'Bring containers? When?', action: 'I need some'),
    // Transport
    PostTopic(id: 'ride_offer', sector: Sector.transport, kind: PostKind.offer, label: 'Offer a lift', icon: Icons.directions_car_outlined,
        titleHint: 'e.g. To town, Monday 07:00, 3 seats', detailsHint: 'Route, time, shared petrol cost', action: 'Ask for a seat'),
    PostTopic(id: 'ride_request', sector: Sector.transport, kind: PostKind.request, label: 'Need a lift', icon: Icons.hail_outlined,
        titleHint: 'e.g. To the clinic, Friday 09:00', detailsHint: 'Where, when, how many people', action: 'I can help'),
    PostTopic(id: 'lend_item', sector: Sector.transport, kind: PostKind.offer, label: 'Lend something', icon: Icons.handyman_outlined,
        titleHint: 'e.g. Wheelbarrow, ladder, trailer', detailsHint: 'How long, any deposit', action: 'Ask to borrow'),
    PostTopic(id: 'access_issue', sector: Sector.transport, kind: PostKind.check, label: 'Road or access problem', icon: Icons.report_problem_outlined,
        titleHint: 'e.g. Flooded road by the bridge, no streetlight', detailsHint: 'Who it affects: wheelchairs, prams, walking at night', action: 'Seen it too'),
    // Prepare
    PostTopic(id: 'prepare_offer', sector: Sector.prepare, kind: PostKind.offer, label: 'I can help in an emergency', icon: Icons.volunteer_activism_outlined,
        titleHint: 'e.g. Generator, first aid training, bakkie', detailsHint: 'What you can do and when to call', action: 'Good to know'),
  ];
}

/// A community post. Firestore: posts/{id}
class CommunityPost {
  CommunityPost({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.areaId,
    required this.topic,
    required this.title,
    required this.createdAt,
    this.areaName = '',
    this.ward = '',
    this.details = '',
    this.place = '',
    this.contact = '',
    this.quality,
    this.target,
    this.members = const [],
    this.open = true,
    this.expiresAt,
    this.pilot = false,
    this.pilotHousehold,
  });

  final String id;
  final String uid;
  final String displayName;
  final String areaId;
  final String areaName;
  final String ward;
  final PostTopic topic;
  final String title;
  final String details;

  /// A rough place, never an exact address ("By the school gate").
  final String place;

  /// Optional WhatsApp number the poster chose to share.
  final String contact;
  final WaterQuality? quality;

  /// Group buys: how many households are needed.
  final int? target;

  /// Users who tapped the action ("joined", "interested").
  final List<String> members;
  final bool open;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool pilot;
  final String? pilotHousehold;

  Sector get sector => topic.sector;
  int get responses => members.length;
  bool isActive(DateTime now) => open && (expiresAt == null || expiresAt!.isAfter(now));
  bool isFull() => target != null && members.length >= target!;

  CommunityPost copyWith({List<String>? members, bool? open}) => CommunityPost(
        id: id,
        uid: uid,
        displayName: displayName,
        areaId: areaId,
        areaName: areaName,
        ward: ward,
        topic: topic,
        title: title,
        details: details,
        place: place,
        contact: contact,
        quality: quality,
        target: target,
        members: members ?? this.members,
        open: open ?? this.open,
        createdAt: createdAt,
        expiresAt: expiresAt,
        pilot: pilot,
        pilotHousehold: pilotHousehold,
      );

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'householdId': pilotHousehold ?? uid,
        'displayName': displayName,
        'areaId': areaId,
        'areaName': areaName,
        'ward': ward,
        'sector': sector.wire,
        'topic': topic.id,
        'kind': topic.kind.wire,
        'title': title,
        'details': details,
        'place': place,
        'contact': contact,
        'quality': quality?.wire,
        'target': target,
        'members': members,
        'open': open,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'day': _day(createdAt),
        'source': pilot ? 'pilot' : 'app',
        'pilot': pilot,
        if (pilotHousehold != null) 'pilotHousehold': pilotHousehold,
      };

  factory CommunityPost.fromMap(String id, Map<String, dynamic> m) => CommunityPost(
        id: id,
        uid: m['uid'] as String? ?? '',
        displayName: m['displayName'] as String? ?? 'Neighbour',
        areaId: m['areaId'] as String? ?? '',
        areaName: m['areaName'] as String? ?? '',
        ward: m['ward'] as String? ?? '',
        topic: PostTopic.byId(m['topic'] as String?),
        title: m['title'] as String? ?? '',
        details: m['details'] as String? ?? '',
        place: m['place'] as String? ?? '',
        contact: m['contact'] as String? ?? '',
        quality: WaterQuality.fromWireOrNull(m['quality'] as String?),
        target: (m['target'] as num?)?.toInt(),
        members: List<String>.from((m['members'] as List?) ?? const []),
        open: m['open'] != false,
        createdAt: _date(m['createdAt']),
        expiresAt: _dateOrNull(m['expiresAt']),
        pilot: m['pilot'] == true,
        pilotHousehold: m['pilotHousehold'] as String?,
      );
}

/// What a household may need in an emergency. Kept private: only the owner
/// (and the ward dashboard, as counts) can see it. No medical details.
enum NeedKind {
  powerEquipment('power_equipment', 'Needs electricity for equipment', Icons.electrical_services_outlined),
  mobility('mobility', 'Someone can\'t walk far or use stairs', Icons.accessible_outlined),
  water('water', 'Needs help getting water', Icons.water_drop_outlined),
  young('young_or_old', 'Babies or elderly at home', Icons.child_friendly_outlined),
  other('other', 'Something else', Icons.more_horiz);

  const NeedKind(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;
  static NeedKind fromWire(String? v) => _fromWire(values, v, (e) => e.wire, other);
}

/// Firestore: households/{uid}/needs/{id}
class HouseholdNeed {
  HouseholdNeed({required this.id, required this.kind, required this.createdAt, this.note = ''});
  final String id;
  final NeedKind kind;
  final String note;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {'kind': kind.wire, 'note': note, 'createdAt': createdAt};

  factory HouseholdNeed.fromMap(String id, Map<String, dynamic> m) => HouseholdNeed(
        id: id,
        kind: NeedKind.fromWire(m['kind'] as String?),
        note: m['note'] as String? ?? '',
        createdAt: _date(m['createdAt']),
      );
}
