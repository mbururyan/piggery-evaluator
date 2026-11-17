import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/number_tile.dart';
import '../../widgets/section_widgets.dart';
import 'section_router.dart';

/// Section 11: pigs the farmer plans to deliver to FCL, month by month,
/// for the 12 months starting with the visit month. The paper's Jan–Dec
/// boxes, put in order, so a November visit's plan doesn't mix this
/// January with next January.
///
/// Blank = none planned, so every save stores all 12 months (blanks as 0)
/// and the section counts as done once saved.
class IntakeSectionScreen extends StatefulWidget {
  const IntakeSectionScreen({super.key, required this.visit});

  final Visit visit;

  @override
  State<IntakeSectionScreen> createState() => _IntakeSectionScreenState();
}

class _IntakeSectionScreenState extends State<IntakeSectionScreen> {
  static const _section = VisitSection.intake;
  static const _mon = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late final List<DateTime> _months = IntakeTemplate.monthsFrom(widget.visit.visitDate);
  late final TileFields _f;
  late final TextEditingController _remark;
  bool _saved = false;

  bool get _locked => widget.visit.isLocked;

  @override
  void initState() {
    super.initState();
    final existing = widget.visit.section(_section);
    _f = TileFields(
      _months.map(IntakeTemplate.keyOf).toList(),
      initial: IntakeTemplate.monthsOf(existing) ?? const {},
      onFocusChange: () {
        if (mounted) setState(() {});
      },
    );
    _remark = TextEditingController(text: existing?['remark'] as String? ?? '');
  }

  @override
  void dispose() {
    _f.dispose();
    _remark.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _payload => {
        'months': {for (final id in _f.ids) id: _f.intOf(id) ?? 0},
        'remark': _remark.text.trim(),
      };

  void _save() {
    if (_locked || _saved) return;
    if (!_f.anyTyped && _remark.text.trim().isEmpty &&
        widget.visit.section(_section) == null) {
      return; // opened and left untouched: stays "not started"
    }
    VisitService.instance.saveSection(widget.visit, _section, _payload);
    _saved = true;
  }

  /// "Nov 26". The year matters: the plan crosses New Year.
  String _label(DateTime m) =>
      '${_mon[m.month - 1]} ${(m.year % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = _f.ids.fold<int>(0, (n, id) => n + (_f.intOf(id) ?? 0));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: SectionPage(
        section: _section,
        locked: _locked,
        footerNote: 'Blank = none planned',
        onSaveAndNext: _locked
            ? null
            : () {
                // Save & next on an untouched screen still counts: "no
                // deliveries planned" is a real answer.
                // So it saves even when untouched (_save() would skip).
                VisitService.instance.saveSection(widget.visit, _section, _payload);
                _saved = true;
                openNextSection(
                    context, widget.visit.withSection(_section, _payload), _section);
              },
        children: [
          SectionCard(children: [
            SectionTitle('Pigs to deliver to FCL',
                subtitle: '${_label(_months.first)} – ${_label(_months.last)}'),
            TileGrid(perRow: 3, children: [
              for (final m in _months) _tile(IntakeTemplate.keyOf(m), _label(m)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 9),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line))),
              child: Row(children: [
                const Text('Next 12 months',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const Spacer(),
                Text('$total pigs',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ),
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