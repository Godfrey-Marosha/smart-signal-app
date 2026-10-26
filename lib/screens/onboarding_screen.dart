import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/household.dart';
import '../state/app_state.dart';
import '../widgets/account_menu.dart';

/// One short page after first sign-in. Every field feeds a forecast.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.existing});

  /// When set, edits this household instead of creating one.
  final Household? existing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _ward = TextEditingController();
  final _litres = TextEditingController();
  final _budget = TextEditingController();
  int _people = 1;
  bool _prepaid = true;
  bool _consent = false;
  bool _saving = false;

  static const _examples = ['Soweto', 'Tembisa', 'Mamelodi', 'Khayelitsha'];

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    if (h != null) {
      _name.text = h.displayName;
      _area.text = h.areaName;
      _ward.text = h.ward;
      _litres.text = h.storageLitres == 0 ? '' : '${h.storageLitres}';
      _budget.text = h.electricityBudgetCents == 0 ? '' : '${h.electricityBudgetCents ~/ 100}';
      _people = h.people;
      _prepaid = h.prepaid;
      _consent = h.consent;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) {
      final user = AppScope.of(context).user;
      _name.text = user?.displayName ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _area, _ward, _litres, _budget]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_consent) {
      _show('Please agree to the privacy terms to continue.');
      return;
    }
    final state = AppScope.of(context);
    await _submit(Household(
      id: state.repo.uid,
      ownerUid: state.repo.uid,
      displayName: _name.text.trim(),
      areaId: slug(_area.text),
      areaName: _area.text.trim(),
      ward: _ward.text.trim(),
      people: _people,
      prepaid: _prepaid,
      storageLitres: int.tryParse(_litres.text.trim()) ?? 0,
      electricityBudgetCents: ((double.tryParse(_budget.text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0) * 100).round(),
      consent: _consent,
      createdAt: widget.existing?.createdAt,
    ));
  }

  /// Saves and always clears the spinner, showing what went wrong if needed.
  Future<void> _submit(Household h) async {
    if (_saving) return;
    final state = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await state.saveHousehold(h);
      if (!mounted) return;
      if (widget.existing != null) navigator.pop();
    } catch (e) {
      debugPrint('Street Signal: saveHousehold failed: $e');
      final text = '$e';
      _show(text.contains('permission-denied')
          ? 'The server refused the save. Deploy the Firestore rules (firebase deploy --only firestore:rules) and try again.'
          : text.contains('not-found') || text.contains('NOT_FOUND')
              ? 'No Firestore database yet. Create it in the Firebase console, then try again.'
              : 'Could not save your home. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit household' : 'Set up your home'),
        actions: [
          if (!editing && state.isDemo)
            TextButton(
              onPressed: _saving ? null : () => _submit(Household.demo(uid: state.repo.uid, name: _name.text.trim().isEmpty ? 'Thandi' : _name.text.trim())),
              child: const Text('Use demo household'),
            ),
          const AccountMenu(),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!editing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('Five quick questions so we can warn you before water or power goes off.'),
                    ),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Your name'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _area,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Suburb or area', helperText: 'Forecasts use reports from this area'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter your area' : null,
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    for (final a in _examples) ActionChip(label: Text(a), onPressed: () => setState(() => _area.text = a)),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(controller: _ward, decoration: const InputDecoration(labelText: 'Ward (optional)', hintText: 'e.g. Ward 12')),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Expanded(child: Text('People in your home')),
                    IconButton(onPressed: _people > 1 ? () => setState(() => _people--) : null, icon: const Icon(Icons.remove_circle_outline)),
                    SizedBox(width: 28, child: Text('$_people', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(onPressed: _people < 20 ? () => setState(() => _people++) : null, icon: const Icon(Icons.add_circle_outline)),
                  ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _prepaid,
                    onChanged: (v) => setState(() => _prepaid = v),
                    title: const Text('Prepaid electricity'),
                    subtitle: const Text('We forecast when your units will run out'),
                  ),
                  if (_prepaid) ...[
                    TextFormField(
                      controller: _budget,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monthly electricity budget (optional)', prefixText: 'R '),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _litres,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Water you can store (optional)', suffixText: 'litres', hintText: 'e.g. 60'),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                    title: const Text('Use my reports and readings to make forecasts'),
                    subtitle: const Text('Your area sees reports, never your name or address. You can delete your data at any time.'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(editing ? 'Save' : 'Start'),
                  ),
                ],
              ),
            ),
    );
  }
}
