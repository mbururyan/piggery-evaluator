import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_widgets.dart';
import 'section_router.dart';

/// Section 8: breed (dropdown + Other), four yes/no rows, highest parity.
class BreedingSectionScreen extends StatefulWidget {
  const BreedingSectionScreen({super.key, required this.visit});

  final Visit visit;

  @override
  State<BreedingSectionScreen> createState() => _BreedingSectionScreenState();
}

class _BreedingSectionScreenState extends State<BreedingSectionScreen> {
  static const _section = VisitSection.breeding;

  String? _breed;
  late final TextEditingController _breedOther;
  final _yesNo = <String, bool>{};
  int? _parity;
  late final TextEditingController _remark;
  bool _saved = false;

  bool get _locked => widget.visit.isLocked;

  @override
  void initState() {
    super.initState();
    final d = widget.visit.section(_section) ?? const {};
    final b = d['breed'] as String?;
    // An unknown stored breed would crash the dropdown: only keep known ones.
    _breed = BreedingTemplate.breeds.contains(b) ? b : null;
    _breedOther = TextEditingController(text: d['breed_other'] as String? ?? '');
    for (final r in BreedingTemplate.yesNoRows) {
      if (d[r.$1] is bool) _yesNo[r.$1] = d[r.$1] as bool;
    }
    _parity = (d['highest_parity'] as num?)?.toInt();
    _remark = TextEditingController(text: d['remark'] as String? ?? '');
  }

  @override
  void dispose() {
    _breedOther.dispose();
    _remark.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _payload => {
        if (_breed != null) 'breed': _breed,
        // Only meaningful with "Other"; cleared otherwise so a changed
        // breed doesn't leave stale text behind.
        'breed_other': _breed == 'Other' ? _breedOther.text.trim() : null,
        ..._yesNo,
        if (_parity != null) 'highest_parity': _parity,
        'remark': _remark.text.trim(),
      };

  void _save() {
    if (_locked || _saved) return;
    final touched = _breed != null || _yesNo.isNotEmpty || _parity != null ||
        _remark.text.trim().isNotEmpty;
    if (!touched && widget.visit.section(_section) == null) return;
    VisitService.instance.saveSection(widget.visit, _section, _payload);
    _saved = true;
  }

  void _touch(VoidCallback f) => setState(() {
        f();
        _saved = false;
      });

  @override
  Widget build(BuildContext context) {
    final complete = BreedingTemplate.isComplete(_payload);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: SectionPage(
        section: _section,
        locked: _locked,
        // Every question is optional (23 Nov): no "not finished" nagging.
        footerNote: complete ? 'Score ${BreedingTemplate.score(_payload)}' : null,
        onSaveAndNext: _locked
            ? null
            : () {
                _save();
                openNextSection(context,
                    widget.visit.withSection(_section, _payload), _section);
              },
        children: [
          SectionCard(children: [
            const Text('Breed', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _breed,
              isExpanded: true,
              dropdownColor: AppColors.white,
              hint: const Text('Select breed',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
              items: [
                for (final b in BreedingTemplate.breeds)
                  DropdownMenuItem(value: b, child: Text(b)),
              ],
              onChanged: _locked ? null : (v) => _touch(() => _breed = v),
            ),
            if (_breed == 'Other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _breedOther,
                enabled: !_locked,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _touch(() {}),
                decoration: const InputDecoration(hintText: 'Which breed?'),
              ),
            ],
          ]),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            children: [
              for (final r in BreedingTemplate.yesNoRows)
                _row(
                  r.$2,
                  AnswerSegment(
                    // Yes/No; "No" is only orange on the two scored rows
                    // (FCL source, replacement programme). On sync and AI
                    // it's amber: recorded, not held against the farm.
                    options: [
                      const AnswerOption(true, 'Yes', Tone.good),
                      AnswerOption(false, 'No', r.$3 ? Tone.bad : Tone.warn),
                    ],
                    value: _yesNo[r.$1],
                    enabled: !_locked,
                    onChanged: (v) => _touch(() => _yesNo[r.$1] = v as bool),
                  ),
                ),
              _row(
                'Highest parity',
                _Stepper(
                  value: _parity,
                  enabled: !_locked,
                  onChanged: (v) => _touch(() => _parity = v),
                ),
                last: true,
              ),
            ],
          ),
          RemarkField(controller: _remark, enabled: !_locked),
        ],
      ),
    );
  }

  Widget _row(String label, Widget trailing, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.ink))),
          const SizedBox(width: 8),
          trailing,
        ]),
      );
}

/// − value + : easier one-handed than typing. Starts empty ("—") rather
/// than 0, so "not asked yet" and "zero" are never confused.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.enabled, required this.onChanged});

  final int? value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, int? next) => SizedBox(
          width: 36,
          height: 36,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: AppColors.inputBorder),
              foregroundColor: AppColors.ink,
            ),
            onPressed: enabled && next != null ? () => onChanged(next) : null,
            child: Icon(icon, size: 18),
          ),
        );

    final v = value;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove, v == null || v <= 0 ? null : v - 1),
      SizedBox(
        width: 40,
        child: Text(v?.toString() ?? '—',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      // First tap of + from empty sets 1; parity above 15 is implausible.
      btn(Icons.add, v == null ? 1 : (v >= 15 ? null : v + 1)),
    ]);
  }
}