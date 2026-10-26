import 'package:flutter/material.dart';

import '../core/format.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const version = '1.0.0';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = false;

  Future<void> _loadPilot() async {
    final state = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load pilot history?'),
        content: Text(
          'Adds an 8-week pilot for ${state.household!.areaName}: 46 households, about 30 water and power outages, '
          '13 community posts across food, energy, water, transport and preparedness, and 6 weeks of '
          'electricity readings and forecasts for your home. Everything is marked as pilot data. '
          'Use this for demos until real reports build up.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Load')),
        ],
      ),
    );
    if (ok != true) return;
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

  Future<void> _signOut() async {
    final state = AppScope.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    await state.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // Signed out (or household removed) while this screen is still on its
    // way off: draw nothing instead of crashing on a missing household.
    if (state.household == null || state.user == null) return const Scaffold();
    final h = state.household!;
    final user = state.user;
    final via = switch (user?.provider) { 'google' => 'Google', 'apple' => 'Apple', 'demo' => 'Demo', _ => 'Email' };

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(user?.email ?? h.displayName),
            subtitle: Text('Signed in with $via'),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(h.displayName),
            subtitle: Text('${h.areaName}${h.ward.isEmpty ? '' : ' · ${h.ward}'} · ${h.people} people'
                '${h.prepaid ? ' · prepaid' : ''}${h.electricityBudgetCents > 0 ? ' · budget ${rands(h.electricityBudgetCents)}' : ''}'),
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnboardingScreen(existing: h))),
              child: const Text('Edit'),
            ),
          ),
          const Divider(),
          if (!state.isDemo && !state.hasPilotHistory)
            ListTile(
              leading: const Icon(Icons.history_toggle_off),
              title: const Text('Load pilot history'),
              subtitle: const Text('8 weeks of sample outages for your area, so forecasts and impact work in a demo'),
              trailing: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _loading ? null : _loadPilot,
            ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Data source'),
            subtitle: Text(state.isDemo ? 'Demo mode (nothing leaves this phone)' : 'Live (Firebase)'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Your data'),
            subtitle: Text('Your area sees your reports, never your name or address. Ward views are aggregated. '
                'You can ask for your data to be deleted at any time.'),
            isThreeLine: true,
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Street Signal'),
            subtitle: Text('The early signal for your street · v${SettingsScreen.version}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
}
