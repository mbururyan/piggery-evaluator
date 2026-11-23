import 'package:flutter/material.dart';

import '../constants/visit_template.dart';
import '../theme/app_theme.dart';

/// Colours for an answer's tone. Brand red is never used: problems are
/// burnt orange, the same rule as everywhere else.
(Color fg, Color bg) toneColors(Tone t) => switch (t) {
      Tone.good => (AppColors.green, AppColors.greenTint),
      Tone.warn => (AppColors.amberText, AppColors.amberTint),
      Tone.bad => (AppColors.alert, AppColors.alertTint),
    };

/// A row of answer buttons (Yes / No, Okay / Needs attention, Good /
/// Fair / Poor). The chosen one fills with its tone's colour, so a page
/// of answers reads at a glance: green good, amber fair, orange a problem.
///
/// [expand] stretches the buttons to share the full width: used when
/// they sit under the question, where left-aligned chips looked ragged.
class AnswerSegment extends StatelessWidget {
  const AnswerSegment({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.expand = false,
  });

  final List<AnswerOption> options;
  final Object? value;
  final ValueChanged<Object> onChanged;
  final bool enabled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          expand ? Expanded(child: _chip(options[i])) : _chip(options[i]),
        ],
      ],
    );
  }

  Widget _chip(AnswerOption o) {
    final selected = o.value == value;
    final (fg, bg) = toneColors(o.tone);
    return Material(
      color: selected ? bg : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
            color: selected ? fg : AppColors.inputBorder,
            width: selected ? 1.2 : 0.8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: enabled ? () => onChanged(o.value) : null,
        child: Padding(
          // Big enough to hit with a thumb while holding a clipboard.
          padding: EdgeInsets.symmetric(horizontal: 11, vertical: expand ? 10 : 8),
          child: Text(
            o.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? fg : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one remark per section (Ryan, 10 Nov: one under each section, not
/// one per question).
class RemarkField extends StatelessWidget {
  const RemarkField({super.key, required this.controller, this.enabled = true});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SectionCard(children: [
      const Text('Remark',
          style: TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        enabled: enabled,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          // Remarks print on the farmer's PDF (20 Nov), so the EO is told
          // as they write, not after.
          hintText: "Optional: printed on the farmer's report",
        ),
      ),
    ]);
  }
}

/// The bold heading at the top of a card ("Litters", "Breeding stock"),
/// with an optional grey line under it.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ),
          ],
        ),
      );
}

/// White rounded card used throughout the section screens.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// The frame every section screen shares: title, "Section 7 of 10",
/// a read-only notice when the visit is locked, the content, and the
/// "Save & next" button pinned at the bottom.
class SectionPage extends StatelessWidget {
  const SectionPage({
    super.key,
    required this.section,
    required this.locked,
    required this.children,
    required this.onSaveAndNext,
    this.footerNote,
  });

  final VisitSection section;
  final bool locked;
  final List<Widget> children;

  /// Null hides the button (locked visits).
  final VoidCallback? onSaveAndNext;

  /// Small grey line above the button, e.g. "2 left" or "Score 4/5".
  final String? footerNote;

  @override
  Widget build(BuildContext context) {
    final index = VisitSection.values.indexOf(section);
    final isLast = index == VisitSection.values.length - 1;
    final nextLabel =
        isLast ? 'Save & review' : 'Save & next: ${VisitSection.values[index + 1].label}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.ink,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Section ${index + 1} of ${VisitSection.values.length}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              children: [
                if (locked) ...[
                  const SectionCard(children: [
                    Text(
                      'This visit was submitted more than 7 days ago, so it '
                      'can no longer be changed on the phone. Ask the office '
                      'for corrections.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ]),
                  const SizedBox(height: 10),
                ],
                for (final c in children) ...[c, const SizedBox(height: 10)],
              ],
            ),
          ),
          if (onSaveAndNext != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Column(children: [
                if (footerNote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(footerNote!,
                        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ),
                ElevatedButton(onPressed: onSaveAndNext, child: Text(nextLabel)),
              ]),
            ),
        ]),
      ),
    );
  }
}