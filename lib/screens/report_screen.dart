import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/account_menu.dart';

/// Three taps: water or power, what's happening, send.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Service? _service;
  ReportStatus? _status;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final state = AppScope.of(context);
    setState(() => _sending = true);
    try {
      await state.submitReport(_service!, _status!, note: _note.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showDone(context, _status == ReportStatus.backOn ? 'Thanks! Marked as back on.' : 'Report sent. Your area can see it.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showDone(context, 'Could not send the report. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem'), actions: const [AccountMenu()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('What is affected?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            for (final s in Service.values) ...[
              Expanded(
                child: _BigChoice(
                  icon: s.icon,
                  label: s.label,
                  selected: _service == s,
                  onTap: () => setState(() {
                    _service = s;
                    _status = null;
                  }),
                ),
              ),
              if (s != Service.values.last) const SizedBox(width: 12),
            ],
          ]),
          if (_service != null) ...[
            const SizedBox(height: 24),
            Text("What's happening?", style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final st in _service!.statuses)
                ChoiceChip(
                  label: Text(st.label),
                  selected: _status == st,
                  selectedColor: (st == ReportStatus.backOn ? Brand.ok : Brand.amber).withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _status = st),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. Burst pipe on the corner'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _service != null && _status != null && !_sending ? _send : null,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Send report'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 8),
          Text('Your area sees the report, not your name or address.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            Icon(icon, size: 34, color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
