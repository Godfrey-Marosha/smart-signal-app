import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/format.dart';
import '../models/records.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Neighbours offering and asking for water, charging, lifts and food.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  ShareCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final posts = state.activeShares.where((p) => _filter == null || p.category == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Share with neighbours')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _NewPostSheet()),
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
              ),
              for (final c in ShareCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label),
                    selected: _filter == c,
                    onSelected: (_) => setState(() => _filter = c),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            const Card(
              child: EmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'Nothing shared yet',
                message: 'Have spare water, a solar charger or a seat in your car? Post it.',
              ),
            )
          else
            for (final p in posts) _PostCard(post: p, mine: p.uid == state.repo.uid, now: state.now),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.mine, required this.now});
  final SharePost post;
  final bool mine;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOffer = post.kind == ShareKind.offer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(post.category.icon, color: scheme.primary),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isOffer ? scheme.primaryContainer : scheme.tertiaryContainer),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(post.kind.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const Spacer(),
                Text(timeAgo(post.createdAt, now), style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 8),
              Text(post.quantity, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (post.note.isNotEmpty) ...[const SizedBox(height: 4), Text(post.note)],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                    '${mine ? 'You' : post.displayName}${post.availableUntil == null ? '' : ' · until ${whenLabel(post.availableUntil!, now)}'}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (mine)
                  TextButton(
                    onPressed: () {
                      AppScope.of(context).closeShare(post);
                      showDone(context, 'Post closed.');
                    },
                    child: const Text('Close'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: () => showDone(context, 'Contact by WhatsApp comes next (url_launcher).'),
                    child: Text(isOffer ? 'I need this' : 'I can help'),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPostSheet extends StatefulWidget {
  const _NewPostSheet();

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  ShareKind _kind = ShareKind.offer;
  ShareCategory _category = ShareCategory.water;
  int _days = 2;
  final _what = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _what.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_what.text.trim().isEmpty) return;
    await AppScope.of(context).addShare(
      kind: _kind,
      category: _category,
      quantity: _what.text,
      note: _note.text,
      availableFor: Duration(days: _days),
    );
    if (!mounted) return;
    Navigator.pop(context);
    showDone(context, 'Posted to your area.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New post', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<ShareKind>(
              segments: [for (final k in ShareKind.values) ButtonSegment(value: k, label: Text(k == ShareKind.offer ? 'I can offer' : 'I need'))],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final c in ShareCategory.values)
                ChoiceChip(avatar: Icon(c.icon, size: 18), label: Text(c.label), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _what, autofocus: true, decoration: const InputDecoration(labelText: 'What?', hintText: 'e.g. 100 L of water, phone charging')),
            const SizedBox(height: 12),
            TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Details (optional)', hintText: 'When and where, roughly. No exact address.')),
            const SizedBox(height: 12),
            const Text('Show for'),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 1, label: Text('1 day')), ButtonSegment(value: 2, label: Text('2 days')), ButtonSegment(value: 7, label: Text('A week'))],
              selected: {_days},
              onSelectionChanged: (v) => setState(() => _days = v.first),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _post, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('Post')),
          ],
        ),
      ),
    );
  }
}
