import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../logic/prediction_engine.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/account_menu.dart';

/// Prepaid electricity: how long it lasts, the budget, and quick logging.
class ElectricityScreen extends StatelessWidget {
  const ElectricityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final h = state.household!;
    final f = state.electricity;
    final b = state.budget;

    if (!h.prepaid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Electricity'), actions: const [AccountMenu()]),
        body: const EmptyState(
          icon: Icons.bolt_outlined,
          title: 'Postpaid electricity',
          message: 'Run-out forecasts are for prepaid meters. You still get outage alerts for your area.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Electricity'), actions: const [AccountMenu()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (f == null)
            const Card(
              child: EmptyState(
                icon: Icons.speed_outlined,
                title: 'Log your meter to see a forecast',
                message: 'Enter the units left on your meter today and again in a day or two.',
              ),
            )
          else
            _HeadlineCard(daysLeft: f.daysLeft, runOut: f.runOut, unitsLeft: f.unitsLeft, topupCents: f.suggestedTopupCents),
          if (state.usage.length >= 5) ...[
            const SizedBox(height: 10),
            _UsageChart(days: state.usage, change: state.impact?.usageChange),
          ],
          if (b != null) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Budget: ${rands(b.spentCents)} of ${rands(b.budgetCents)} spent this month'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (b.spentCents / b.budgetCents).clamp(0.0, 1.0).toDouble(),
                      minHeight: 10,
                      color: b.isOver ? Brand.danger : Brand.teal,
                    ),
                  ),
                  if (b.isOver) ...[
                    const SizedBox(height: 8),
                    Text('At this rate you\'ll go ${rands(b.overCents)} over.',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Brand.danger)),
                  ],
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _logTopup(context),
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('I bought units'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _logUnitsLeft(context),
                icon: const Icon(Icons.speed_outlined),
                label: const Text('Units left'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Log your meter every day or two for accurate forecasts.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  static double? _num(String s) => double.tryParse(s.replaceAll(',', '.').replaceAll(' ', ''));

  static Future<void> _logTopup(BuildContext context) async {
    final amount = TextEditingController();
    final units = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Electricity bought'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount paid', prefixText: 'R ')),
          const SizedBox(height: 12),
          TextField(controller: units, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Units on the slip', suffixText: 'kWh')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final a = _num(amount.text);
    final u = _num(units.text);
    amount.dispose();
    units.dispose();
    if (ok != true || a == null || u == null || a <= 0 || u <= 0 || !context.mounted) return;
    await AppScope.of(context).addTopup(a, u);
    if (context.mounted) showDone(context, 'Top-up saved. Forecast updated.');
  }

  static Future<void> _logUnitsLeft(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Units left on the meter'),
        content: TextField(controller: c, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'kWh')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final v = _num(c.text);
    c.dispose();
    if (ok != true || v == null || v < 0 || !context.mounted) return;
    await AppScope.of(context).addUnitsLeft(v);
    if (context.mounted) showDone(context, 'Saved. Forecast updated.');
  }
}

/// Daily kWh for the last 14 days, with the change vs the two weeks before.
class _UsageChart extends StatelessWidget {
  const _UsageChart({required this.days, required this.change});
  final List<DailyUsage> days;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = days.map((d) => d.kwh).reduce((a, b) => a > b ? a : b);
    final c = change;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Daily use, last 14 days', style: TextStyle(fontWeight: FontWeight.w600))),
            if (c != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (c <= 0 ? Brand.ok : Brand.danger).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${c <= 0 ? 'Down' : 'Up'} ${percent(c.abs())}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c <= 0 ? Brand.ok : Brand.danger),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        height: max == 0 ? 0 : 80 * d.kwh / max,
                        decoration: BoxDecoration(
                          color: d.day.weekday >= DateTime.saturday ? Brand.amber : theme.colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(weekday(d.day).substring(0, 1), style: theme.textTheme.labelSmall),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
            c == null ? 'Weekends in amber.' : 'Compared with the two weeks before. Weekends in amber.',
            style: theme.textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }
}

/// The one thing to know: how long the electricity lasts and what to buy.
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.daysLeft, required this.runOut, required this.unitsLeft, required this.topupCents});
  final double daysLeft;
  final DateTime runOut;
  final double unitsLeft;
  final int topupCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgent = daysLeft <= 3;
    final days = daysLeft > 60 ? '60+' : daysLeft.toStringAsFixed(daysLeft < 10 ? 1 : 0);
    return Card(
      color: (urgent ? Brand.amber : Brand.teal).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your electricity lasts about', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('$days days', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Runs out around ${weekday(runOut)} ${dayMonth(runOut)} · ${unitsLeft.toStringAsFixed(0)} kWh left'),
          if (urgent) ...[
            const SizedBox(height: 12),
            Text('Buy about ${rands(topupCents)} to last another week.', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }
}
