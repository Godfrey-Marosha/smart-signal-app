import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../logic/prediction_engine.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// The household's numbers, the area outlook and how accurate forecasts are.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = state.now;
    final f = state.electricity;
    final b = state.budget;
    final habit = state.topupHabit;
    final accuracy = state.accuracy;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (accuracy != null) ...[
            const SectionTitle('Forecast accuracy'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_outlined, color: Brand.ok),
                title: Text('${percent(accuracy)} of forecasts came true'),
                subtitle: Text('Based on ${state.answeredCount} answer${state.answeredCount == 1 ? '' : 's'} from you. Keep answering "Did this happen?"'),
              ),
            ),
          ],
          const SectionTitle('Electricity'),
          if (f == null)
            const Card(
              child: EmptyState(
                icon: Icons.speed_outlined,
                title: 'Log your meter to see a forecast',
                message: 'Two readings a few days apart are enough to start.',
              ),
            )
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                StatTile(label: 'Days left', value: f.daysLeft > 60 ? '60+' : f.daysLeft.toStringAsFixed(1), caption: 'Runs out ${weekday(f.runOut)} ${dayMonth(f.runOut)}'),
                StatTile(label: 'Daily use', value: '${f.dailyKwh.toStringAsFixed(1)} kWh', caption: 'Recent days count more'),
                StatTile(label: 'Your tariff', value: 'R${f.tariff.toStringAsFixed(2)}', caption: 'per kWh'),
                StatTile(label: 'Suggested top-up', value: rands(f.suggestedTopupCents), caption: 'About a week of use'),
              ],
            ),
            if (f.usageByDay.length >= 3) ...[
              const SizedBox(height: 10),
              _UsageBars(days: f.usageByDay),
            ],
          ],
          if (b != null) ...[
            const SectionTitle('Electricity budget this month'),
            _BudgetCard(b: b),
          ],
          if (habit != null) ...[
            const SectionTitle('Your habits'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: Text('You usually buy electricity around the ${_ordinal(habit.typicalDay)}'),
                subtitle: Text(
                  'Next expected ${dayMonth(habit.nextExpected)}. '
                  "We'll remind you two days before if you're running low.",
                ),
              ),
            ),
          ],
          const SectionTitle('Next 7 days in your area'),
          if (state.weekWindows.isEmpty)
            const Card(child: EmptyState(icon: Icons.wb_sunny_outlined, title: 'No likely outages this week'))
          else
            Card(
              child: Column(children: [
                for (final w in state.weekWindows.take(8))
                  ListTile(
                    dense: true,
                    leading: Icon(w.service.icon),
                    title: Text('${w.service.label} · ${whenLabel(w.start, now)} to ${hhmm(w.end)}'),
                    trailing: Text(percent(w.probability), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
          ..._durations(state),
          const SectionTitle('Food prices near you'),
          ..._prices(state),
          const SectionTitle('3 ways to save'),
          ..._tips(state).map((t) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(leading: const Icon(Icons.lightbulb_outline, color: Brand.amber), title: Text(t)),
              )),
        ],
      ),
    );
  }

  static String _ordinal(int d) {
    if (d >= 11 && d <= 13) return '${d}th';
    return switch (d % 10) { 1 => '${d}st', 2 => '${d}nd', 3 => '${d}rd', _ => '${d}th' };
  }

  List<Widget> _durations(AppState state) {
    final entries = state.durations.entries.where((e) => e.value != null).toList();
    if (entries.isEmpty) return const [];
    return [
      const SectionTitle('When it goes off, how long?'),
      Card(
        child: Column(children: [
          for (final e in entries)
            ListTile(
              leading: Icon(e.key.icon),
              title: Text('${e.key.label}: usually ${hoursLabel(e.value!.medianHours)}'),
              subtitle: Text('8 in 10 outages are back within ${hoursLabel(e.value!.p80Hours)} (${e.value!.sample} reports)'),
            ),
        ]),
      ),
    ];
  }

  List<Widget> _prices(AppState state) {
    final basket = state.basket;
    final trends = state.priceTrends.take(5).toList();
    if (basket == null && trends.isEmpty) {
      return const [Card(child: EmptyState(icon: Icons.sell_outlined, title: 'Not enough prices yet', message: 'Log a few shelf prices from the Log tab.'))];
    }
    return [
      if (basket != null)
        Card(
          color: Brand.teal.withValues(alpha: 0.08),
          child: ListTile(
            leading: const Icon(Icons.shopping_basket_outlined),
            title: Text('Cheapest basket: ${basket.cheapestStore}'),
            subtitle: Text('${rands(basket.savingCents)} less than ${basket.dearestStore} for the same ${basket.items} items'),
          ),
        ),
      if (trends.isNotEmpty) ...[
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            for (final t in trends)
              ListTile(
                dense: true,
                title: Text(t.item),
                subtitle: Text('Now about ${rands(t.latestCents)}'),
                trailing: Text(
                  '${t.change >= 0 ? '+' : ''}${percent(t.change)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.change > 0.03 ? Brand.danger : (t.change < -0.03 ? Brand.ok : null)),
                ),
              ),
          ]),
        ),
      ],
    ];
  }

  List<String> _tips(AppState state) {
    final h = state.household!;
    final f = state.electricity;
    final tips = <String>[];
    if (f != null && f.dailyKwh > 9) {
      final saving = (2 * 30 * f.tariff).round();
      tips.add('Put the geyser on a timer (2 hours a day). Typical saving: about R$saving a month.');
    }
    if (h.storage != WaterStorage.none) {
      tips.add('Top up stored water the evening before a likely outage, not on the day, when pressure is already low.');
    } else {
      tips.add('Keep two 25 L containers filled; they cover a family for most outages in your area.');
    }
    final basket = state.basket;
    if (basket != null) {
      tips.add('Buy the basics at ${basket.cheapestStore} and save about ${rands(basket.savingCents)} each shop.');
    }
    tips.add('Cook with a lid on and batch-cook on outage days to save electricity and gas.');
    return tips.take(3).toList();
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.b});
  final BudgetForecast b;

  @override
  Widget build(BuildContext context) {
    final ratio = b.budgetCents == 0 ? 0.0 : (b.spentCents / b.budgetCents).clamp(0.0, 1.0).toDouble();
    final over = b.isOver;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${rands(b.spentCents)} spent of ${rands(b.budgetCents)}'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: ratio, minHeight: 10, color: over ? Brand.danger : Brand.teal),
            ),
            const SizedBox(height: 8),
            Text(
              over
                  ? 'Projected ${rands(b.projectedCents)}: ${rands(b.overCents)} over budget.'
                  : 'Projected ${rands(b.projectedCents)}: within budget.',
              style: TextStyle(fontWeight: FontWeight.w600, color: over ? Brand.danger : Brand.ok),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple bar chart of daily kWh, no chart package needed.
class _UsageBars extends StatelessWidget {
  const _UsageBars({required this.days});
  final List<DailyUsage> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = days.map((d) => d.kwh).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily use, last 14 days (kWh)'),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: max == 0 ? 0 : 80 * d.kwh / max,
                              decoration: BoxDecoration(
                                color: d.day.weekday >= DateTime.saturday ? Brand.amber : scheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(weekday(d.day).substring(0, 1), style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('Weekends in amber', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
