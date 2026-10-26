import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/records.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/account_menu.dart';
import 'community_screen.dart';
import 'shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final h = state.household!;
    final now = state.now;
    final open = state.openByService;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_greeting(now)}, ${h.displayName}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(h.ward.isEmpty ? h.areaName : '${h.areaName} · ${h.ward}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: const [AccountMenu()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (state.isDemo) const _Banner('Demo mode: area history is sample pilot data.'),
          if (!state.isDemo && state.reports.isEmpty) const _NoHistoryCard(),
          _StatusBanner(open: open, areaName: h.areaName),
          const SizedBox(height: 12),
          const _QuickActions(),
          SectionTitle('Next 48 hours', trailing: Text(dayMonth(now))),
          if (state.predictions.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.wb_sunny_outlined,
                title: 'Nothing expected near you',
                message: state.reports.isEmpty
                    ? 'Forecasts start once your area has a few weeks of reports. Report outages when they happen.'
                    : 'Keep reporting outages; forecasts get sharper with every report.',
              ),
            )
          else
            for (final p in state.predictions.take(3)) ...[
              ForecastCard(
                p,
                done: state.isDone(p),
                onDone: () {
                  state.markDone(p);
                  showDone(context, 'Great. That counts towards your impact.');
                },
              ),
              const SizedBox(height: 10),
            ],
          for (final p in state.pendingFeedback.take(1)) ...[
            _FeedbackCard(p: p),
            const SizedBox(height: 10),
          ],
          ..._communityPreview(context, state),
          SectionTitle('Alerts for ${h.areaName}'),
          if (state.alerts.isEmpty)
            const Card(child: EmptyState(icon: Icons.notifications_none, title: 'No alerts right now'))
          else
            for (final a in state.alerts.take(2)) _AlertTile(alert: a, now: now),
        ],
      ),
    );
  }
}

String _greeting(DateTime now) => now.hour < 12 ? 'Good morning' : now.hour < 18 ? 'Good afternoon' : 'Good evening';

/// The two newest community posts, with a link to the Community tab.
List<Widget> _communityPreview(BuildContext context, AppState state) {
  final recent = state.posts.where((p) => p.isActive(state.now)).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (recent.isEmpty) return const [];
  return [
    SectionTitle(
      'From your neighbours',
      trailing: TextButton(onPressed: () => ShellNav.of(context)?.goTo(Tabs.community), child: const Text('See all')),
    ),
    for (final p in recent.take(2)) PostCard(post: p),
  ];
}

/// One clear line: all clear, or what's off right now.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.open, required this.areaName});
  final Map<Service, List<ServiceReport>> open;
  final String areaName;

  @override
  Widget build(BuildContext context) {
    final clear = open.isEmpty;
    final color = clear ? Brand.ok : Brand.amber;
    final text = clear
        ? 'All clear in $areaName right now'
        : open.entries
            .map((e) => '${e.key.label} ${e.value.first.status == ReportStatus.lowPressure ? 'low' : 'off'} '
                '(${e.value.length} report${e.value.length == 1 ? '' : 's'})')
            .join(' · ');
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(clear ? Icons.check_circle : Icons.warning_amber_rounded, color: clear ? Brand.ok : const Color(0xFF8A5A00), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(clear ? 'Water and power are on' : 'Happening now', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(text),
          ]),
        ),
      ]),
    );
  }
}

/// The three things people do most, one tap away.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final nav = ShellNav.of(context);
    return Row(children: [
      _Action(icon: Icons.campaign_outlined, label: 'Report a problem', onTap: () => openReport(context)),
      const SizedBox(width: 8),
      _Action(icon: Icons.bolt_outlined, label: 'My electricity', onTap: () => nav?.goTo(Tabs.electricity)),
      const SizedBox(width: 8),
      _Action(icon: Icons.diversity_3_outlined, label: 'Find or offer help', onTap: () => nav?.goTo(Tabs.community)),
    ]);
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(children: [
              Icon(icon, color: scheme.onPrimaryContainer),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Live mode with an empty area: offer the pilot data so the demo has history.
class _NoHistoryCard extends StatefulWidget {
  const _NoHistoryCard();

  @override
  State<_NoHistoryCard> createState() => _NoHistoryCardState();
}

class _NoHistoryCardState extends State<_NoHistoryCard> {
  bool _loading = false;

  Future<void> _load() async {
    final state = AppScope.of(context);
    setState(() => _loading = true);
    try {
      await state.loadPilotHistory();
      if (mounted) showDone(context, 'Pilot history loaded. Forecasts updated.');
    } catch (e) {
      if (mounted) showDone(context, 'Could not load pilot history: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your area has no history yet', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Forecasts learn from weeks of reports. For a demo, load the 8-week pilot: 46 households, '
                'about 30 outages, 13 community posts, and your home\'s last 6 weeks of electricity.'),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: _loading ? null : _load,
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Load pilot history'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Brand.amber.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.science_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.p});
  final Prediction p;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    void answer(String a) {
      state.answer(p, a);
      showDone(context, 'Thanks. This makes the next forecast better.');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Did this happen?', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(p.title),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.tonal(onPressed: () => answer('yes'), child: const Text('Yes')),
              OutlinedButton(onPressed: () => answer('partly'), child: const Text('Partly')),
              OutlinedButton(onPressed: () => answer('no'), child: const Text('No')),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.now});
  final AlertItem alert;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: ServiceAvatar(alert.service, alert: alert.source == AlertSource.official),
          title: Text(alert.title),
          subtitle: Text('${alert.body}\n${alert.source.label} · ${timeAgo(alert.sentAt, now)}'),
          isThreeLine: true,
        ),
      ),
    );
  }
}
