import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';

/// The "Me" tab: your home, what Street Signal has done for you and your
/// area, and settings.
class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // Signed out (or household removed) while this screen is still on its
    // way off: draw nothing instead of crashing on a missing household.
    if (state.household == null || state.user == null) return const Scaffold();
    final h = state.household!;
    final me = state.impact;
    final area = state.area;
    final hasMine = me != null && (me.outagesWarned > 0 || me.runOutsAvoided > 0);
    final myPosts = state.posts.where(state.isMine).toList();
    final helped = myPosts.fold(0, (s, p) => s + p.responses);
    final joined = state.posts.where(state.hasJoined).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Brand.teal,
                foregroundColor: Colors.white,
                child: Text(h.displayName.isEmpty ? '?' : h.displayName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              title: Text(h.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${h.areaName}${h.ward.isEmpty ? '' : ' · ${h.ward}'} · ${h.people} at home'),
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnboardingScreen(existing: h))),
                child: const Text('Edit'),
              ),
            ),
          ),
          const SectionTitle('What Street Signal did for you'),
          if (!hasMine)
            const Card(
              child: EmptyState(
                icon: Icons.insights_outlined,
                title: 'Your impact builds up here',
                message: 'Tap "Done" when you act on a forecast, and answer "Did this happen?" afterwards.',
              ),
            )
          else
            Card(
              child: Column(children: [
                _Line(
                  icon: Icons.notifications_active_outlined,
                  big: '${me.outagesWarned}',
                  text: 'outages you knew about in advance'
                      '${me.avgWarningHours == null ? '' : ', about ${me.avgWarningHours!.round()} hours before'}',
                ),
                const Divider(height: 1),
                _Line(icon: Icons.bolt_outlined, big: '${me.runOutsAvoided}', text: 'times you topped up before running out'),
                const Divider(height: 1),
                _Line(icon: Icons.water_drop_outlined, big: '${me.litresStored} L', text: 'water stored before a cut'),
              ]),
            ),
          if (me?.accuracy != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.verified_outlined, size: 18, color: Brand.ok),
              const SizedBox(width: 6),
              Expanded(child: Text('Forecasts were right ${percent(me!.accuracy!)} of the time (${me.forecastsChecked} checked by you).')),
            ]),
          ],
          if (myPosts.isNotEmpty || joined > 0) ...[
            const SectionTitle('You and your neighbours'),
            Card(
              child: Column(children: [
                _Line(icon: Icons.campaign_outlined, big: '${myPosts.length}', text: 'things you shared, $helped responses from neighbours'),
                const Divider(height: 1),
                _Line(icon: Icons.handshake_outlined, big: '$joined', text: 'times you joined or helped a neighbour'),
              ]),
            ),
          ],
          SectionTitle('In ${h.areaName}'),
          if (area == null || area.reports == 0)
            const Card(child: EmptyState(icon: Icons.groups_outlined, title: 'No reports in your area yet'))
          else
            Card(
              child: Column(children: [
                _Line(icon: Icons.groups_outlined, big: '${area.households}', text: 'households reporting'),
                const Divider(height: 1),
                _Line(
                  icon: Icons.report_outlined,
                  big: '${area.outages}',
                  text: 'outages in ${area.weeks} weeks'
                      '${area.water == null ? '' : ', usually fixed within ${hoursLabel(area.water!.medianHours)}'}',
                ),
                const Divider(height: 1),
                _Line(
                  icon: Icons.volunteer_activism_outlined,
                  big: '${state.posts.where((p) => p.isActive(state.now)).length}',
                  text: 'active community posts: food, water, lifts and more',
                ),
                if (area.worstTime != null) ...[
                  const Divider(height: 1),
                  _Line(
                    icon: Icons.schedule,
                    big: area.worstTime!.split(' · ').first,
                    text: 'most likely time for an outage (${area.worstTime!.split(' · ').last})',
                  ),
                ],
              ]),
            ),
          if (state.hasPilotHistory) ...[
            const SizedBox(height: 16),
            Text(
              'Includes pilot data (8 weeks). Real reports replace it as neighbours join.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// One big number with a short sentence next to it.
class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.big, required this.text});
  final IconData icon;
  final String big;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(big, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
