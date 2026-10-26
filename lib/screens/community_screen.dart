import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/community.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/account_menu.dart';
import 'new_post_screen.dart';

/// Neighbours coordinating food, energy, water, transport and emergency help.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  Sector _sector = Sector.food;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final posts = state.activePosts(_sector);

    return Scaffold(
      appBar: AppBar(title: Text('Community · ${state.household!.areaName}'), actions: const [AccountMenu()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewPostScreen(sector: _sector), fullscreenDialog: true)),
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
        children: [
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in Sector.values)
                  _SectorTile(
                    sector: s,
                    count: state.activeCount(s),
                    selected: s == _sector,
                    onTap: () => setState(() => _sector = s),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_sector.tagline, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_sector == Sector.energy) ...[const SizedBox(height: 12), const _EnergyTimingCard()],
                if (_sector == Sector.water) ...[const SizedBox(height: 12), const _WaterQualityCard()],
                if (_sector == Sector.prepare) ...[const SizedBox(height: 12), const _NeedsCard()],
                SectionTitle(_sector == Sector.prepare ? 'Neighbours who can help' : 'Near you'),
                if (posts.isEmpty)
                  Card(
                    child: EmptyState(
                      icon: _sector.icon,
                      title: 'Nothing here yet',
                      message: 'Be the first: tap "Post" to share with ${state.household!.areaName}.',
                    ),
                  )
                else
                  for (final p in posts) PostCard(post: p),
                const SizedBox(height: 8),
                const _ComingNextTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectorTile extends StatelessWidget {
  const _SectorTile({required this.sector, required this.count, required this.selected, required this.onTap});
  final Sector sector;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = sector.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected ? c.withValues(alpha: 0.18) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? c : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(sector.icon, size: 30, color: c),
                const SizedBox(height: 6),
                Text(sector.label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                Text(count == 0 ? ' ' : '$count active', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One community post with a clear action.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});
  final CommunityPost post;

  Future<void> _whatsApp(BuildContext context) async {
    var digits = post.contact.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = '27${digits.substring(1)}';
    final text = Uri.encodeComponent('Hi ${post.displayName}, about your Street Signal post: ${post.title}');
    final ok = await launchUrl(Uri.parse('https://wa.me/$digits?text=$text'), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showDone(context, 'Could not open WhatsApp.');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final c = post.sector.color;
    final mine = state.isMine(post);
    final joined = state.hasJoined(post);
    final now = state.now;
    final meta = [
      post.topic.label,
      if (post.place.isNotEmpty) post.place,
      '${post.displayName}, ${timeAgo(post.createdAt, now)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(backgroundColor: c.withValues(alpha: 0.15), child: Icon(post.topic.icon, color: c)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(post.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(meta, style: theme.textTheme.bodySmall),
                  ]),
                ),
              ]),
              if (post.quality != null) ...[
                const SizedBox(height: 10),
                _Chip(text: post.quality!.label, color: post.quality!.color),
              ],
              if (post.details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(post.details),
              ],
              if (post.target != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (post.members.length / post.target!).clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    color: c,
                  ),
                ),
                const SizedBox(height: 4),
                Text(post.isFull() ? 'Group is full' : '${post.members.length} of ${post.target} households joined',
                    style: theme.textTheme.bodySmall),
              ],
              if (post.expiresAt != null) ...[
                const SizedBox(height: 4),
                Text('Until ${whenLabel(post.expiresAt!, now)}', style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Row(children: [
                if (post.target == null && post.responses > 0)
                  Expanded(child: Text('${post.responses} responded', style: theme.textTheme.bodySmall))
                else
                  const Spacer(),
                if (post.contact.isNotEmpty && !mine)
                  IconButton(
                    tooltip: 'WhatsApp ${post.displayName}',
                    onPressed: () => _whatsApp(context),
                    icon: const Icon(Icons.chat_outlined),
                  ),
                if (mine)
                  TextButton(
                    onPressed: () {
                      state.closePost(post);
                      showDone(context, 'Post closed.');
                    },
                    child: const Text('Close post'),
                  )
                else if (joined)
                  OutlinedButton.icon(
                    onPressed: () => state.toggleJoin(post),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(post.topic.kind == PostKind.group ? 'Joined' : 'Done'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: post.isFull()
                        ? null
                        : () {
                            state.toggleJoin(post);
                            showDone(context, post.contact.isEmpty
                                ? '${post.displayName} can see you responded.'
                                : 'Tap the chat icon to message ${post.displayName} on WhatsApp.');
                          },
                    child: Text(post.topic.action),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      );
}

/// Energy: when to run the geyser, washing machine and iron.
class _EnergyTimingCard extends StatelessWidget {
  const _EnergyTimingCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = state.energyTiming;
    final next = t.nextCut;
    return Card(
      color: Sector.energy.color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Best times to use power', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _TimingRow(icon: Icons.check_circle_outline, color: Brand.ok, label: 'Run the washing machine, iron and geyser', value: t.best),
          const SizedBox(height: 6),
          _TimingRow(icon: Icons.do_not_disturb_on_outlined, color: Brand.danger, label: 'Avoid heavy use', value: t.avoid),
          if (next != null) ...[
            const SizedBox(height: 6),
            _TimingRow(
              icon: Icons.power_off_outlined,
              color: const Color(0xFF8A5A00),
              label: 'Next likely power cut here',
              value: '${whenLabel(next.start, state.now)} to ${hhmm(next.end)}',
            ),
          ],
          const SizedBox(height: 8),
          Text('Using power outside peak hours eases the strain on the grid and helps prevent load reduction.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ]);
}

/// Water: what neighbours say about the tap water this week.
class _WaterQualityCard extends StatelessWidget {
  const _WaterQualityCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = state.waterQuality;
    final latest = q.latest;
    final quality = latest?.quality;
    final color = quality?.color ?? Sector.water.color;
    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Water in your area', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (latest == null)
            const Text('No checks this week. If your water looks or smells wrong, post a quality check.')
          else ...[
            Text('Latest: ${quality?.label ?? 'Checked'}${latest.place.isEmpty ? '' : ' (${latest.place})'}, ${timeAgo(latest.createdAt, state.now)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(q.problems == 0
                ? 'No problems reported this week.'
                : '${q.problems} problem${q.problems == 1 ? '' : 's'} reported this week. Boil water if unsure.'),
          ],
        ]),
      ),
    );
  }
}

/// Prepare: private list of what this household would need in an emergency.
class _NeedsCard extends StatelessWidget {
  const _NeedsCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock_outline, size: 18),
            const SizedBox(width: 6),
            const Expanded(child: Text('Your emergency needs', style: TextStyle(fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => _addNeed(context), child: const Text('Add')),
          ]),
          const Text('Private: only you can see this. Your ward sees totals only, so help reaches the right homes first.'),
          if (state.needs.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final n in state.needs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(n.kind.icon),
                title: Text(n.kind.label),
                subtitle: n.note.isEmpty ? null : Text(n.note),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => state.removeNeed(n),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  static Future<void> _addNeed(BuildContext context) async {
    final state = AppScope.of(context);
    final note = TextEditingController();
    var kind = NeedKind.powerEquipment;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('What might your home need?', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final k in NeedKind.values)
              ListTile(
                onTap: () => setSheet(() => kind = k),
                selected: k == kind,
                leading: Icon(k.icon),
                title: Text(k.label),
                trailing: Icon(k == kind ? Icons.check_circle : Icons.circle_outlined),
                contentPadding: EdgeInsets.zero,
              ),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'No medical details needed')),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save privately')),
          ]),
        ),
      ),
    );
    final text = note.text;
    note.dispose();
    if (ok != true) return;
    await state.addNeed(kind, note: text);
    if (context.mounted) showDone(context, 'Saved privately.');
  }
}

/// Ideas that need hardware, shown honestly as what comes next.
class _ComingNextTile extends StatelessWidget {
  const _ComingNextTile();

  static const _items = [
    (Icons.solar_power_outlined, 'Community solar dashboard', 'Track shared solar and split the savings'),
    (Icons.grass_outlined, 'Garden soil sensors', 'Water community gardens only when needed'),
    (Icons.propane_tank_outlined, 'Rain tank monitors', 'See how much rainwater is stored before a storm'),
    (Icons.thermostat_outlined, 'Home energy audits', 'Borrow a thermal camera to find heat leaks'),
    (Icons.air_outlined, 'Street weather sensors', 'Local heat, flood and air-quality warnings'),
    (Icons.cell_tower_outlined, 'Offline messaging', 'Keep texting neighbours when the network is down'),
    (Icons.map_outlined, 'Map view', 'See gardens, taps and charging spots on a map'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.rocket_launch_outlined),
        title: const Text('Coming next'),
        subtitle: const Text('Ideas we\'re building with partners'),
        children: [
          for (final (icon, title, line) in _items)
            ListTile(dense: true, leading: Icon(icon), title: Text(title), subtitle: Text(line)),
        ],
      ),
    );
  }
}
