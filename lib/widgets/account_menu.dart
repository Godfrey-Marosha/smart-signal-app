import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// The ⋮ menu at the top right of every screen except "Me" (which has
/// Settings and its own Sign out). Shows who is signed in, and Log out.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  Future<void> _logOut(BuildContext context) async {
    final state = AppScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign in again at any time. Your reports and readings stay saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true) return;
    // Close any pushed screens (report, new post) so sign-in shows cleanly.
    navigator.popUntil((r) => r.isFirst);
    await state.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final who = user?.email ?? user?.displayName;
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      onSelected: (v) {
        if (v == 'logout') _logOut(context);
      },
      itemBuilder: (_) => [
        if (who != null && who.isNotEmpty)
          PopupMenuItem<String>(
            enabled: false,
            child: Text('Signed in as $who', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (who != null && who.isNotEmpty) const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Log out'),
          ),
        ),
      ],
    );
  }
}
