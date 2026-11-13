import 'package:flutter/material.dart';

import '../constants/kenya_locations.dart';
import '../models/farmer.dart';
import '../services/farmer_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'farmer_detail_screen.dart';

/// Registers a new farmer, or edits one when [existing] is given.
/// Same fields and checks either way; only the write differs.
class RegisterFarmerScreen extends StatefulWidget {
  const RegisterFarmerScreen({super.key, this.existing});

  final Farmer? existing;

  @override
  State<RegisterFarmerScreen> createState() => _RegisterFarmerScreenState();
}

class _RegisterFarmerScreenState extends State<RegisterFarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();

  String? _county;
  String? _subcounty;
  bool _saving = false;

  /// Possible duplicates from the last check. Non-empty = the warning is
  /// showing and the button reads "Register anyway".
  List<DuplicateHit> _dupes = const [];

  /// The phone + ID the warning was shown for. If the EO changes either,
  /// the old warning no longer applies, so we check again.
  String? _dupesCheckedFor;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    if (f == null) return;
    _nameCtrl.text = f.name;
    _mobileCtrl.text = f.mobile;
    _idCtrl.text = f.idNumber ?? '';
    _emailCtrl.text = f.email ?? '';
    _wardCtrl.text = f.location.ward ?? '';
    // A stored county the dropdown doesn't know (e.g. a spelling from the
    // seed file) would crash DropdownButton, so only preselect known ones.
    if (KenyaLocations.counties.contains(f.location.county)) {
      _county = f.location.county;
      if (KenyaLocations.subcountiesOf(_county)
          .contains(f.location.subcounty)) {
        _subcounty = f.location.subcounty;
      }
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _idCtrl.dispose();
    _emailCtrl.dispose();
    _wardCtrl.dispose();
    super.dispose();
  }

  FarmerLocation get _location => FarmerLocation(
        county: _county!,
        subcounty: _subcounty!,
        ward: _wardCtrl.text,
      );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    // --- Duplicate check (warns, never blocks: one person can own two
    //     farms). Skipped when the EO already saw the warning for this
    //     exact phone + ID and chose "Register anyway". ---
    final checkKey = '${_mobileCtrl.text.trim()}|${_idCtrl.text.trim()}';
    if (_dupesCheckedFor != checkKey) {
      final hits = await FarmerService.instance.findDuplicates(
        mobile: _mobileCtrl.text,
        idNumber: _idCtrl.text,
        excludeId: widget.existing?.id,
      );
      if (!mounted) return;
      _dupesCheckedFor = checkKey;
      if (hits.isNotEmpty) {
        setState(() {
          _dupes = hits;
          _saving = false;
        });
        // The warning sits at the top of the form; bring it into view.
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        return;
      }
    }

    if (_isEdit) {
      FarmerService.instance.update(
        farmerId: widget.existing!.id,
        name: _nameCtrl.text,
        mobile: _mobileCtrl.text,
        idNumber: _idCtrl.text,
        email: _emailCtrl.text,
        location: _location,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_nameCtrl.text.trim()} updated'),
        backgroundColor: AppColors.green,
      ));
      return;
    }

    final result = FarmerService.instance.register(
      name: _nameCtrl.text,
      mobile: _mobileCtrl.text,
      idNumber: _idCtrl.text,
      email: _emailCtrl.text,
      location: _location,
    );

    // Already saved on the phone. This only asks whether the server has
    // it too, so the message can tell the EO the truth.
    var synced = true;
    try {
      await result.serverAck.timeout(const Duration(seconds: 2));
    } catch (_) {
      synced = false;
    }
    if (!mounted) return;

    final name = _nameCtrl.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(synced
          ? '$name registered and synced'
          : '$name saved on this phone · will sync when online'),
      backgroundColor: synced ? AppColors.green : AppColors.amber,
      duration: const Duration(seconds: 4),
    ));

    // Straight to the new farmer's page, where "Start a visit" is the
    // next tap. pushReplacement so Back skips the now-finished form.
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => FarmerDetailScreen(farmerId: result.id)));
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            text: text,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
            children: [
              if (required)
                const TextSpan(
                    text: ' *', style: TextStyle(color: AppColors.alert)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final subcounties = KenyaLocations.subcountiesOf(_county);

    return Scaffold(
      // White like login: a form page, not a list of cards.
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(_isEdit ? 'Edit farmer' : 'Register farmer',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUnfocus,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_dupes.isNotEmpty) ...[
                  _DuplicateWarning(hits: _dupes),
                  const SizedBox(height: 14),
                ],

                _label('Name of farm / owner', required: true),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'e.g. Achieng Rose Farm'),
                  validator: (v) => Validators.required(v, 'Name'),
                ),
                const SizedBox(height: 16),

                _label('Mobile', required: true),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      hintText: '07xx or 01xx, or +254…'),
                  validator: Validators.kenyanPhone,
                ),
                const SizedBox(height: 16),

                _label('ID number'),
                TextFormField(
                  controller: _idCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      hintText: 'Optional, but helps match old records'),
                  // Optional, but if typed it must look like a real ID:
                  // the old app is full of "20" and "00" placeholders.
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    return RegExp(r'^\d{6,9}$').hasMatch(t)
                        ? null
                        : 'ID numbers are 6–9 digits';
                  },
                ),
                const SizedBox(height: 16),

                _label('Email'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'Optional'),
                  validator: Validators.optionalEmail,
                ),
                const SizedBox(height: 16),

                _label('County', required: true),
                DropdownButtonFormField<String>(
                  initialValue: _county,
                  isExpanded: true,
                  dropdownColor: AppColors.white,
                  hint: const Text('Select county',
                      style: TextStyle(fontSize: 14, color: AppColors.muted)),
                  items: [
                    for (final c in KenyaLocations.counties)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() {
                    _county = v;
                    // The old sub-county belongs to the county just left.
                    _subcounty = null;
                  }),
                  // Overrides the form's on-blur rule: opening a dropdown
                  // counts as losing focus, which would show the error
                  // before the EO had a chance to choose (same as RE).
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) => v == null ? 'County cannot be blank' : null,
                ),
                const SizedBox(height: 16),

                _label('Sub-county', required: true),
                DropdownButtonFormField<String>(
                  // Keyed by county so it rebuilds cleanly when the county
                  // changes, instead of holding a stale selection.
                  key: ValueKey(_county),
                  initialValue: _subcounty,
                  isExpanded: true,
                  dropdownColor: AppColors.white,
                  hint: Text(
                    _county == null ? 'Pick a county first' : 'Select sub-county',
                    style: const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                  items: [
                    for (final s in subcounties)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  // A null handler is how Flutter greys out a dropdown.
                  onChanged: _county == null
                      ? null
                      : (v) => setState(() => _subcounty = v),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) =>
                      v == null ? 'Sub-county cannot be blank' : null,
                ),
                const SizedBox(height: 16),

                _label('Ward'),
                TextFormField(
                  controller: _wardCtrl,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'Type the ward (optional)'),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : Text(_isEdit
                          ? 'Save changes'
                          : (_dupes.isNotEmpty
                              ? 'Register anyway'
                              : 'Register farmer')),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEdit
                      ? 'Saves on this phone straight away and syncs when online.'
                      : 'Saved as PF pending. The office assigns the PF.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The amber "possible duplicate" box at the top of the form.
class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning({required this.hits});

  final List<DuplicateHit> hits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amberTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Possible duplicate',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.amberText)),
          const SizedBox(height: 4),
          for (final h in hits)
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FarmerDetailScreen(farmerId: h.farmer.id))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(TextSpan(
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.amberText),
                  children: [
                    TextSpan(
                        text: h.farmer.title,
                        style: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600)),
                    TextSpan(text: ' has the ${h.reason}'),
                    if (h.farmer.assignedEoName.isNotEmpty)
                      TextSpan(text: ' (EO: ${h.farmer.assignedEoName})'),
                  ],
                )),
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'Tap a name to check it. If this is a different farm, register anyway.',
            style: TextStyle(fontSize: 11.5, color: AppColors.amberText),
          ),
        ],
      ),
    );
  }
}