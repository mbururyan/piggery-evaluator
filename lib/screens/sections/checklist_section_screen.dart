import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_widgets.dart';
import 'section_router.dart';

/// One screen, five sections: Biosecurity, Herd health, Records, Feeds
/// and Housing. Everything that differs between them (questions, answer
/// choices, which answers score) comes from the [template].
class ChecklistSectionScreen extends StatefulWidget {
  const ChecklistSectionScreen({
    super.key,
    required this.visit,
    required this.template,
  });

  final Visit visit;
  final ChecklistTemplate template;

  @override
  State<ChecklistSectionScreen> createState() => _ChecklistSectionScreenState();
}

class _ChecklistSectionScreenState extends State<ChecklistSectionScreen> {
  late final Map<String, dynamic> _answers;
  late final TextEditingController _remark;

  /// Set once saved, so leaving via Back doesn't save a second time.
  bool _saved = false;

  VisitSection get _section => widget.template.section;
  bool get _locked => widget.visit.isLocked;

  @override
  void initState() {
    super.initState();
    final existing = widget.visit.section(_section) ?? const {};
    _answers = {
      for (final r in widget.template.rows)
        if (existing.containsKey(r.id)) r.id: existing[r.id],
    };
    _remark = TextEditingController(text: existing['remark'] as String? ?? '');
  }

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _payload => {
        ..._answers,
        'remark': _remark.text.trim(),
      };

  /// Saves whatever is answered so far. Partial is fine: the hub shows
  /// the section as "in progress" until every row is answered.
  void _save() {
    if (_locked || _saved) return;
    // Nothing touched on an empty section: don't create an empty map,
    // or the hub would call it "in progress".
    if (_answers.isEmpty && _remark.text.trim().isEmpty &&
        widget.visit.section(_section) == null) {
      return;
    }
    VisitService.instance.saveSection(widget.visit, _section, _payload);
    _saved = true;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final answered = t.answered(_answers);
    final left = t.rows.length - answered;

    // Saving on the way out, by Back button or gesture, means the EO can
    // leave mid-section and lose nothing.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: SectionPage(
        section: _section,
        locked: _locked,
        // The score only appears once everything is answered: a running
        // score mid-section reads like a mark for questions not asked yet.
        footerNote: left == 0 ? 'Score ${t.score(_answers)}' : '$left left',
        onSaveAndNext: _locked
            ? null
            : () {
                _save();
                openNextSection(
                    context, widget.visit.withSection(_section, _payload), _section);
              },
        children: [
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            children: [
              for (var i = 0; i < t.rows.length; i++)
                _QuestionRow(
                  row: t.rows[i],
                  options: t.optionsFor(t.rows[i]),
                  value: _answers[t.rows[i].id],
                  enabled: !_locked,
                  last: i == t.rows.length - 1,
                  onChanged: (v) => setState(() {
                    _answers[t.rows[i].id] = v;
                    _saved = false;
                  }),
                ),
            ],
          ),
          RemarkField(controller: _remark, enabled: !_locked),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.row,
    required this.options,
    required this.value,
    required this.enabled,
    required this.last,
    required this.onChanged,
  });

  final ChecklistRow row;
  final List<AnswerOption> options;
  final Object? value;
  final bool enabled;
  final bool last;
  final ValueChanged<Object> onChanged;

  @override
  Widget build(BuildContext context) {
    // Three answers, or long ones ("Needs attention"), don't fit beside
    // the label on a narrow phone, so they go underneath. Short Yes/No
    // pairs sit on the right.
    final stacked =
        options.length > 2 || options.any((o) => o.label.length > 8);

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.label,
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink)),
        if (row.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(row.hint!,
                style: const TextStyle(fontSize: 11, color: AppColors.alert)),
          ),
      ],
    );
    final answers = AnswerSegment(
      options: options,
      value: value,
      enabled: enabled,
      expand: stacked,
      onChanged: onChanged,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border:
            last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 8), answers],
            )
          : Row(children: [Expanded(child: label), const SizedBox(width: 8), answers]),
    );
  }
}