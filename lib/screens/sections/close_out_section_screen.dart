import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_widgets.dart';
import 'section_router.dart';

/// The last section, "Recommendations" (the paper's close-out). Two
/// parts: what happened to last visit's recommendations (only when there
/// were some), and up to five for this visit, at least one required.
///
/// 23 Nov (Ryan): "ready for market now" and the follow-up question were
/// dropped to shorten the visit. The file keeps its old name so nothing
/// that imports it has to change.
class CloseOutSectionScreen extends StatefulWidget {
  const CloseOutSectionScreen({super.key, required this.visit});

  final Visit visit;

  @override
  State<CloseOutSectionScreen> createState() => _CloseOutSectionScreenState();
}

class _CloseOutSectionScreenState extends State<CloseOutSectionScreen> {
  static const _maxRecs = 5;
  static const _outcomes = [
    AnswerOption('done', 'Done', Tone.good),
    AnswerOption('partly', 'Partly', Tone.warn),
    AnswerOption('not_done', 'Not done', Tone.bad),
  ];

  final _recs = <TextEditingController>[];

  /// Null while still looking up the last visit; empty if there's nothing
  /// to review.
  List<RecReview>? _reviews;
  bool _touched = false;
  bool _saved = false;

  Visit get _v => widget.visit;
  bool get _locked => _v.isLocked;

  @override
  void initState() {
    super.initState();
    for (final r in _v.recommendations) {
      _recs.add(TextEditingController(text: r));
    }
    if (_recs.isEmpty) _recs.add(TextEditingController());

    // The review list is copied onto THIS visit the first time the
    // section opens, so it stays the same even if the old visit is
    // edited later.
    if (_v.data.containsKey('last_recs_review')) {
      _reviews = [..._v.lastRecsReview];
    } else {
      _loadPrevious();
    }
  }

  Future<void> _loadPrevious() async {
    final prev = await VisitService.instance
        .previousRecommendations(_v.farmerId, exceptVisitId: _v.id);
    if (!mounted) return;
    setState(() {
      _reviews = [for (final t in prev?.recs ?? const <String>[]) RecReview(t, null)];
    });
  }

  @override
  void dispose() {
    for (final c in _recs) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch(VoidCallback f) => setState(() {
        f();
        _touched = true;
        _saved = false;
      });

  List<String> get _cleanRecs => _recs
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .take(_maxRecs)
      .toList();

  void _save() {
    if (_locked || _saved || !_touched) return;
    VisitService.instance.saveRecommendations(
      _v,
      recommendations: _cleanRecs,
      // Null while still loading: don't save an empty list, or the last
      // visit's recommendations would never be looked up again.
      lastRecsReview: _reviews,
    );
    _saved = true;
  }

  /// The same fields saveRecommendations writes, so Review sees this visit
  /// as it now stands without waiting for the write.
  Map<String, dynamic> get _fields => {
        'recommendations': _cleanRecs,
        if (_reviews != null)
          'last_recs_review': _reviews!.map((r) => r.toMap()).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final hasRec = _cleanRecs.isNotEmpty;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: SectionPage(
        section: VisitSection.closeOut,
        locked: _locked,
        footerNote: hasRec ? 'all done' : 'Add at least one recommendation',
        onSaveAndNext: _locked
            ? null
            : () {
                _touched = true; // pressing the button counts as touching
                _save();
                openNextSection(context, _v.withFields(_fields), VisitSection.closeOut);
              },
        children: [
          if (_reviews == null)
            const SectionCard(children: [
              Text('Checking the last visit…',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ])
          else if (_reviews!.isNotEmpty)
            SectionCard(children: [
              const SectionTitle("Last visit's recommendations",
                  subtitle: 'What happened since?'),
              for (var i = 0; i < _reviews!.length; i++) _reviewRow(i),
            ]),
          SectionCard(children: [
            // No "Up to 5" caption (20 Nov, Ryan): the Add button simply
            // disappears at five, which says it on its own.
            const SectionTitle('Recommendations for this visit'),
            for (var i = 0; i < _recs.length; i++) _recRow(i),
            if (_recs.length < _maxRecs && !_locked)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _touch(() => _recs.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add recommendation'),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _reviewRow(int i) {
    final r = _reviews![i];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: i == _reviews!.length - 1
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${i + 1}. ${r.text}',
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink)),
        const SizedBox(height: 8),
        AnswerSegment(
          options: _outcomes,
          value: r.outcome,
          expand: true,
          enabled: !_locked,
          onChanged: (v) => _touch(() => _reviews![i] = RecReview(r.text, v as String)),
        ),
      ]),
    );
  }

  // Keyed by its controller so removing box 2 of 4 takes box 2's text
  // field with it, instead of shifting every box's text up by one.
  Widget _recRow(int i) => Padding(
        key: ObjectKey(_recs[i]),
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
            width: 20,
            child: Text('${i + 1}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
          Expanded(
            child: TextField(
              controller: _recs[i],
              enabled: !_locked,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _touch(() {}),
              // No example text in the box (20 Nov, Ryan): it read like an
              // answer already filled in.
            ),
          ),
          if (!_locked)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
              onPressed: () => _touch(() {
                // The last box is cleared rather than removed, so there's
                // always one to type in.
                if (_recs.length == 1) {
                  _recs.first.clear();
                } else {
                  // Disposed after the frame: the text field still holds
                  // it until this rebuild finishes.
                  final gone = _recs.removeAt(i);
                  WidgetsBinding.instance.addPostFrameCallback((_) => gone.dispose());
                }
              }),
            ),
        ]),
      );
}