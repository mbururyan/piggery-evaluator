import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/number_tile.dart';
import '../../widgets/section_widgets.dart';
import 'section_router.dart';

/// Section 10: pigs by age band (0–1 … 7+ months) plus gilts, sows and
/// boars. The bands feed the slaughter projections, so their keys never
/// change (see PopulationTemplate).
///
/// Blank = 0, but only when the EO presses Save & next: that's the
/// "I've counted everything" moment. Leaving with Back saves just what's
/// typed, and the section stays in progress until it's finished.
class PopulationSectionScreen extends StatefulWidget {
  const PopulationSectionScreen({super.key, required this.visit});

  final Visit visit;

  @override
  State<PopulationSectionScreen> createState() => _PopulationSectionScreenState();
}

class _PopulationSectionScreenState extends State<PopulationSectionScreen> {
  static const _section = VisitSection.population;

  late final TileFields _f;
  late final TextEditingController _remark;
  bool _saved = false;

  bool get _locked => widget.visit.isLocked;

  @override
  void initState() {
    super.initState();
    final existing = widget.visit.section(_section) ?? const <String, dynamic>{};
    _f = TileFields(
      PopulationTemplate.allKeys.toList(),
      initial: existing,
      onFocusChange: () {
        if (mounted) setState(() {});
      },
    );
    _remark = TextEditingController(text: existing['remark'] as String? ?? '');
  }

  @override
  void dispose() {
    _f.dispose();
    _remark.dispose();
    super.dispose();
  }

  /// [blanksAsZero] on Save & next only (see the class comment).
  Map<String, dynamic> _payload({required bool blanksAsZero}) => {
        for (final id in _f.ids)
          if (_f.intOf(id) != null)
            id: _f.intOf(id)
          else if (blanksAsZero)
            id: 0,
        'remark': _remark.text.trim(),
      };

  void _save({required bool blanksAsZero}) {
    if (_locked || _saved) return;
    if (!_f.anyTyped && !blanksAsZero && _remark.text.trim().isEmpty &&
        widget.visit.section(_section) == null) {
      return; // opened and left untouched
    }
    VisitService.instance
        .saveSection(widget.visit, _section, _payload(blanksAsZero: blanksAsZero));
    _saved = true;
  }

  Future<void> _saveAndNext() async {
    // Every box blank on Save & next is more likely a slip than a farm
    // with no pigs at all, so ask before saving eleven zeros.
    if (!_f.anyTyped) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: AppColors.white,
          title: const Text('No pigs at all?', style: TextStyle(fontSize: 17)),
          content: const Text(
            'Every box is empty. Saving records this farm as having no pigs today.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Go back')),
            TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Yes, none')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _save(blanksAsZero: true);
    if (!mounted) return;
    openNextSection(context,
        widget.visit.withSection(_section, _payload(blanksAsZero: true)), _section);
  }

  int _sum(Iterable<String> ids) => ids.fold(0, (n, id) => n + (_f.intOf(id) ?? 0));

  @override
  Widget build(BuildContext context) {
    final bandIds = PopulationTemplate.bands.map((b) => b.$1);
    final growing = _sum(bandIds);
    final blanks = _f.ids.where((id) => _f.text(id).isEmpty).length;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save(blanksAsZero: false);
      },
      child: SectionPage(
        section: _section,
        locked: _locked,
        footerNote: blanks == 0 ? 'all filled in' : '$blanks blank · saved as 0',
        onSaveAndNext: _locked ? null : _saveAndNext,
        children: [
          SectionCard(children: [
            const SectionTitle('Growing pigs by age', subtitle: 'Age in months'),
            TileGrid(perRow: 4, children: [
              for (final b in PopulationTemplate.bands) _tile(b.$1, b.$2),
            ]),
            const SizedBox(height: 10),
            _TotalLine('Growing pigs', growing),
          ]),
          SectionCard(children: [
            const SectionTitle('Breeding stock'),
            TileGrid(perRow: 3, children: [
              for (final s in PopulationTemplate.stock) _tile(s.$1, s.$2),
            ]),
          ]),
          RemarkField(controller: _remark, enabled: !_locked),
        ],
      ),
    );
  }

  Widget _tile(String id, String label) => NumberTile(
        label: label,
        compact: true,
        controller: _f.ctrl[id]!,
        focusNode: _f.focus[id]!,
        action: _f.actionFor(id),
        onSubmitted: () => _f.next(id),
        onChanged: () => setState(() => _saved = false),
        enabled: !_locked,
      );
}

/// "Growing pigs  64": worked out live, never stored (it's always
/// recalculated from the bands, so it can't disagree with them).
class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: 9),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const Spacer(),
          Text('$value',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
      );
}