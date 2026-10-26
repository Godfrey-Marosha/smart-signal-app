import 'package:flutter/material.dart';

import '../models/community.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/account_menu.dart';

/// Share something with the area: pick what it is, then a few short fields.
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key, required this.sector});
  final Sector sector;

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  late Sector _sector = widget.sector;
  late PostTopic _topic = PostTopic.forSector(widget.sector).first;
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _place = TextEditingController();
  final _contact = TextEditingController();
  WaterQuality _quality = WaterQuality.cloudy;
  int _target = 5;
  int? _days = 3;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _details, _place, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _post() async {
    if (_title.text.trim().isEmpty) {
      showDone(context, 'Please add a short title.');
      return;
    }
    setState(() => _saving = true);
    try {
      await AppScope.of(context).addPost(
        topic: _topic,
        title: _title.text,
        details: _details.text,
        place: _place.text,
        contact: _contact.text,
        quality: _topic.hasQuality ? _quality : null,
        target: _topic.hasTarget ? _target : null,
        lasts: _days == null ? null : Duration(days: _days!),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showDone(context, 'Posted to your area.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showDone(context, 'Could not post. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Share with your area'), actions: const [AccountMenu()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Which area of life?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in Sector.values)
              ChoiceChip(
                avatar: Icon(s.icon, size: 18, color: s.color),
                label: Text(s.label),
                selected: s == _sector,
                onSelected: (_) => setState(() {
                  _sector = s;
                  _topic = PostTopic.forSector(s).first;
                }),
              ),
          ]),
          const SizedBox(height: 20),
          Text('What are you sharing?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final t in PostTopic.forSector(_sector))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: t == _topic ? _sector.color.withValues(alpha: 0.12) : null,
              child: ListTile(
                leading: Icon(t.icon, color: _sector.color),
                title: Text(t.label),
                trailing: Icon(t == _topic ? Icons.check_circle : Icons.circle_outlined, color: t == _topic ? _sector.color : null),
                onTap: () => setState(() => _topic = t),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Title', hintText: _topic.titleHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Details (optional)', hintText: _topic.detailsHint),
          ),
          if (_topic.hasQuality) ...[
            const SizedBox(height: 16),
            Text('How is the water?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in WaterQuality.values)
                ChoiceChip(
                  label: Text(q.label),
                  selected: q == _quality,
                  selectedColor: q.color.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _quality = q),
                ),
            ]),
          ],
          if (_topic.hasTarget) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('Households needed')),
              IconButton(onPressed: _target > 2 ? () => setState(() => _target--) : null, icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(width: 32, child: Text('$_target', textAlign: TextAlign.center, style: theme.textTheme.titleMedium)),
              IconButton(onPressed: _target < 50 ? () => setState(() => _target++) : null, icon: const Icon(Icons.add_circle_outline)),
            ]),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _place,
            decoration: const InputDecoration(labelText: 'Where, roughly (optional)', hintText: 'e.g. By the school gate. No house numbers.'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contact,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp number (optional)',
              hintText: 'Only if you want neighbours to message you',
              prefixIcon: Icon(Icons.chat_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Text('Show it for', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final d in const [1, 3, 7, null])
              ChoiceChip(
                label: Text(d == null ? 'Until I close it' : d == 1 ? '1 day' : d == 7 ? '1 week' : '$d days'),
                selected: d == _days,
                onSelected: (_) => setState(() => _days = d),
              ),
          ]),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _post,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Post'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 8),
          Text('Neighbours in your area see your first name, never your address.',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
