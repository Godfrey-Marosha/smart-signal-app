import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/format.dart';
import '../models/records.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/account_menu.dart';

/// What the area is reporting: your open reports and the last 7 days.
class AreaScreen extends StatefulWidget {
  const AreaScreen({super.key});

  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  Service? _filter;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = state.now;
    final recent = state.reports
        .where((r) => now.difference(r.startedAt).inDays < 7 && (_filter == null || r.service == _filter))
        .toList();
    // The Water / Electricity filter applies to both sections.
    final mine = state.myOpenReports.where((r) => _filter == null || r.service == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: Text(state.household!.areaName), actions: const [AccountMenu()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
            for (final s in Service.values)
              ChoiceChip(
                avatar: Icon(s.icon, size: 18),
                label: Text(s.label),
                selected: _filter == s,
                onSelected: (_) => setState(() => _filter = s),
              ),
          ]),
          if (mine.isNotEmpty) ...[
            const SectionTitle('Your open reports'),
            for (final r in mine)
              Card(
                child: ListTile(
                  leading: ServiceAvatar(r.service, alert: true),
                  title: Text('${r.service.label}: ${r.status.label}'),
                  subtitle: Text('Reported ${timeAgo(r.startedAt, now)}'),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      state.markBackOn(r);
                      showDone(context, 'Marked as back on. Thanks!');
                    },
                    child: const Text('Back on'),
                  ),
                ),
              ),
          ],
          const SectionTitle('Last 7 days'),
          if (recent.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.check_circle_outline,
                title: _filter == null ? 'No reports this week' : 'No ${_filter!.label.toLowerCase()} reports this week',
              ),
            )
          else
            ..._grouped(recent).map((g) => _IncidentTile(group: g, now: now)),
        ],
      ),
    );
  }

  /// Reports for the same service and status within 3 hours = one incident.
  List<List<ServiceReport>> _grouped(List<ServiceReport> reports) {
    final sorted = [...reports]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final groups = <List<ServiceReport>>[];
    for (final r in sorted) {
      final match = groups.where((g) =>
          g.first.service == r.service && g.first.status == r.status && g.first.startedAt.difference(r.startedAt).inHours.abs() < 3);
      if (match.isNotEmpty) {
        match.first.add(r);
      } else {
        groups.add([r]);
      }
    }
    return groups;
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.group, required this.now});
  final List<ServiceReport> group;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final first = group.last;
    final open = group.any((r) => r.isOpen);
    final restored = group.map((r) => r.restoredAt).whereType<DateTime>().toList()..sort();
    final status = open
        ? 'Still ${first.status == ReportStatus.lowPressure ? 'low' : 'out'}'
        : restored.isEmpty
            ? 'Resolved'
            : 'Back at ${hhmm(restored.last)}';
    final count = '${group.length} report${group.length == 1 ? '' : 's'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: ServiceAvatar(first.service, alert: open),
          title: Text('${first.service.label}: ${first.status.label}'),
          subtitle: Text('${whenLabel(first.startedAt, now)} · $status · $count${first.note.isNotEmpty ? '\n${first.note}' : ''}'),
          isThreeLine: first.note.isNotEmpty,
        ),
      ),
    );
  }
}
