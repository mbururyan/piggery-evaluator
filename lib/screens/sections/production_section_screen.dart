import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../services/visit_service.dart';
import '../../widgets/number_tile.dart';
import '../../widgets/section_widgets.dart';
import 'section_router.dart';

/// Section 3: the farm's figures, as number tiles in three groups.
///
/// Rebuilt 17 Nov (Ryan): tiles, each with its target at the foot under
/// a dashed line, and no on-target/below tags while typing. The figures
/// are scored against the target snapshot; the score shows in the footer
/// once all nine are in, and on the hub.
class ProductionSectionScreen extends StatefulWidget {
  const ProductionSectionScreen({super.key, required this.visit});

  final Visit visit;

  @override
  State<ProductionSectionScreen> createState() => _ProductionSectionScreenState();
}

class _ProductionSectionScreenState extends State<ProductionSectionScreen> {
  static const _section = VisitSection.production;

  late final TileFields _f;
  late final TextEditingController _remark;
  bool _saved = false;

  bool get _locked => widget.visit.isLocked;

  @override
  void initState() {
    super.initState();
    final existing = widget.visit.section(_section) ?? const <String, dynamic>{};
    _f = TileFields(
      [for (final g in ProductionTemplate.groups) ...g.$2],
      initial: existing,
      // mounted check: a focused tile loses focus while the screen is
      // being torn down, and setState then would throw.
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

  /// What's typed, as a number, or null if blank/unreadable/out of range.
  num? _value(Kpi k) {
    final t = _f.text(k.id);
    if (t.isEmpty) return null;
    final n = k.decimals ? double.tryParse(t) : int.tryParse(t);
    if (n == null || n < 0) return null;
    if (k.max != null && n > k.max!) return null;
    return n;
  }

  Map<String, dynamic> get _payload => {
        for (final k in ProductionTemplate.kpis)
          if (_value(k) != null) k.id: _value(k),
        'remark': _remark.text.trim(),
      };

  void _save() {
    if (_locked || _saved) return;
    final p = _payload;
    if (p.length == 1 && (p['remark'] as String).isEmpty &&
        widget.visit.section(_section) == null) {
      return; // nothing entered on a fresh section
    }
    VisitService.instance.saveSection(widget.visit, _section, p);
    _saved = true;
  }

  /// "target 13", "target ≤ 5 %", "no target". ≤ only where lower is
  /// better; the unit is only repeated for %, since the number above
  /// already shows it. From the visit's snapshot, so the target the EO
  /// sees is the one the score is checked against.
  String _targetText(Kpi k) {
    final t = widget.visit.targets[k.id];
    if (!k.hasTarget || t == null) return 'no target';
    final sign = k.higherIsBetter ? '' : '≤ ';
    return 'target $sign${TileFields.fmt(t)}${k.unit == '%' ? ' %' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final filled = ProductionTemplate.kpis.where((k) => _value(k) != null).length;
    final score = ProductionTemplate.score(_payload, widget.visit.targets);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: SectionPage(
        section: _section,
        locked: _locked,
        // "5 entered", not "4 left": every figure is optional (23 Nov).
        footerNote: filled == 0
            ? 'Fill in what the farmer knows'
            : '$filled entered${score.of > 0 ? ' · $score on target' : ''}',
        onSaveAndNext: _locked
            ? null
            : () {
                _save();
                openNextSection(context,
                    widget.visit.withSection(_section, _payload), _section);
              },
        children: [
          for (final g in ProductionTemplate.groups)
            SectionCard(children: [
              SectionTitle(g.$1),
              TileGrid(perRow: 2, children: [for (final id in g.$2) _tile(id)]),
            ]),
          RemarkField(controller: _remark, enabled: !_locked),
        ],
      ),
    );
  }

  Widget _tile(String id) {
    final k = ProductionTemplate.byId(id);
    // Typed but not usable (e.g. 150 %): the only time a tile turns
    // orange. Nothing invalid is ever saved.
    final invalid = _f.text(id).isNotEmpty && _value(k) == null;
    // Compact (17 Nov, Ryan): one-line short names, smaller numbers and
    // padding, about a third less height per tile than the first cut.
    return NumberTile(
      label: k.short,
      compact: true,
      unit: k.unit,
      decimals: k.decimals,
      controller: _f.ctrl[id]!,
      focusNode: _f.focus[id]!,
      footer: _targetText(k),
      error: invalid
          ? (k.max != null ? 'Must be 0–${TileFields.fmt(k.max!)}' : 'Check this number')
          : null,
      action: _f.actionFor(id),
      onSubmitted: () => _f.next(id),
      onChanged: () => setState(() => _saved = false),
      enabled: !_locked,
    );
  }
}