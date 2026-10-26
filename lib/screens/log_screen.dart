import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/format.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Quick logging of the numbers that power the forecasts.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final h = state.household!;
    final storage = state.latestReading(ReadingKind.storageLevel);
    return Scaffold(
      appBar: AppBar(title: const Text('Log')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (h.billing == ElectricityBilling.prepaid) ...[
            const SectionTitle('Electricity'),
            _ActionTile(
              icon: Icons.receipt_long_outlined,
              title: 'I bought electricity',
              subtitle: 'Amount and units from your token slip',
              onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _TopupSheet()),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.speed_outlined,
              title: 'Units left on my meter',
              subtitle: state.electricity == null
                  ? 'Log every day or two for accurate forecasts'
                  : 'About ${state.electricity!.unitsLeft.toStringAsFixed(0)} kWh left now',
              onTap: () => _askNumber(context, 'Units left on the meter', 'kWh', (v) => state.addReading(ReadingKind.elecUnits, v)),
            ),
          ],
          const SectionTitle('Water storage'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.storageLitres > 0 ? 'How full is your ${h.storageLitres} L storage?' : 'How much stored water do you have?'),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Empty')),
                      ButtonSegment(value: 25, label: Text('¼')),
                      ButtonSegment(value: 50, label: Text('½')),
                      ButtonSegment(value: 100, label: Text('Full')),
                    ],
                    emptySelectionAllowed: true,
                    selected: storage == null ? <int>{} : {_nearest(storage)},
                    onSelectionChanged: (v) {
                      if (v.isEmpty) return;
                      state.addReading(ReadingKind.storageLevel, v.first.toDouble());
                      showDone(context, 'Water storage updated.');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Food prices'),
          _ActionTile(
            icon: Icons.sell_outlined,
            title: 'Log a shelf price',
            subtitle: 'Helps everyone find the cheapest basket nearby',
            onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _PriceSheet()),
          ),
          const SectionTitle('Recent entries'),
          ..._recent(state),
        ],
      ),
    );
  }

  static int _nearest(double v) => [0, 25, 50, 100].reduce((a, b) => (v - a).abs() <= (v - b).abs() ? a : b);

  List<Widget> _recent(AppState state) {
    final now = state.now;
    final items = <({DateTime at, String text, IconData icon})>[
      for (final t in state.topups) (at: t.date, text: 'Bought ${rands(t.amountCents)} · ${t.units.toStringAsFixed(1)} kWh', icon: Icons.bolt_outlined),
      for (final r in state.readings)
        (
          at: r.at,
          text: r.kind == ReadingKind.storageLevel ? 'Water storage ${r.value.round()}%' : '${r.kind.label}: ${r.value.toStringAsFixed(1)} ${r.kind.unit}',
          icon: r.kind == ReadingKind.storageLevel ? Icons.water_drop_outlined : Icons.speed_outlined,
        ),
      for (final p in state.prices.where((p) => p.uid == state.repo.uid))
        (at: p.at, text: '${p.item} at ${p.store}: ${rands(p.priceCents)}', icon: Icons.sell_outlined),
    ]..sort((a, b) => b.at.compareTo(a.at));
    if (items.isEmpty) {
      return const [Card(child: EmptyState(icon: Icons.edit_note, title: 'Nothing logged yet'))];
    }
    return [
      for (final i in items.take(8))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(i.icon),
          title: Text(i.text),
          trailing: Text(timeAgo(i.at, now)),
        ),
    ];
  }

  static Future<void> _askNumber(BuildContext context, String title, String unit, Future<void> Function(double) save) async {
    final c = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.'))), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (value == null) return;
    await save(value);
    if (context.mounted) showDone(context, 'Saved. Forecast updated.');
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _TopupSheet extends StatefulWidget {
  const _TopupSheet();

  @override
  State<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<_TopupSheet> {
  final _amount = TextEditingController();
  final _units = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _units.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    final units = double.tryParse(_units.text.replaceAll(',', '.'));
    if (amount == null || units == null || amount <= 0 || units <= 0) return;
    await AppScope.of(context).addTopup(amount, units);
    if (!mounted) return;
    Navigator.pop(context);
    showDone(context, 'Top-up saved. Forecast updated.');
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Electricity top-up',
      children: [
        TextField(controller: _amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount paid', prefixText: 'R ')),
        const SizedBox(height: 12),
        TextField(controller: _units, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Units bought', suffixText: 'kWh')),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('Save')),
      ],
    );
  }
}

class _PriceSheet extends StatefulWidget {
  const _PriceSheet();

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  final _store = TextEditingController();
  final _price = TextEditingController();
  String _item = basketItems.first;

  @override
  void dispose() {
    _store.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    if (_store.text.trim().isEmpty || price == null || price <= 0) return;
    await AppScope.of(context).addPrice(_store.text, _item, price);
    if (!mounted) return;
    Navigator.pop(context);
    showDone(context, 'Price saved. Thanks for helping your neighbours.');
  }

  @override
  Widget build(BuildContext context) {
    final stores = AppScope.of(context).knownStores;
    return _Sheet(
      title: 'Shelf price',
      children: [
        TextField(controller: _store, decoration: const InputDecoration(labelText: 'Store')),
        if (stores.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final s in stores) ActionChip(label: Text(s), onPressed: () => setState(() => _store.text = s)),
          ]),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final i in basketItems)
            ChoiceChip(label: Text(i), selected: _item == i, onSelected: (_) => setState(() => _item = i)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price', prefixText: 'R ')),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('Save')),
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
