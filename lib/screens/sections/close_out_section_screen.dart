import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/number_tile.dart';
import '../../widgets/section_widgets.dart';
import 'section_router.dart';

/// The last section: pigs ready for market now, what happened to the
/// last visit's recommendations, up to 5 new ones, and a follow-up date.
///
/// Lives in four top-level fields, not a section map (see the data
/// model), and isn't scored: it's the plan, not a mark.
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
  static const _yesNo = [
    // Both green: a follow-up isn't a bad thing, just a plan.
    AnswerOption(true, 'Yes', Tone.good),
    AnswerOption(false, 'No', Tone.good),
  ];

  late final TileFields _ready;
  final _recs = <TextEditingController>[];

  /// Null while still looking up the last visit; empty if there's nothing
  /// to review.
  List<RecReview>? _reviews;
  bool? _followUp;
  DateTime? _by;
  bool _touched = false;
  bool _saved = false;

  Visit get _v => widget.visit;
  bool get _locked => _v.isLocked;

  @override
  void initState() {
    super.initState();
    _ready = TileFields(
      ['ready_for_market'],
      initial: _v.data,
      onFocusChange: () {
        if (mounted) setState(() {});
      },
    );
    for (final r in _v.recommendations) {
      _recs.add(TextEditingController(text: r));
    }
    if (_recs.isEmpty) _recs.add(TextEditingController());
    _followUp = _v.followUpNeeded;
    _by = _v.followUpBy;

    // The review list is copied onto THIS visit the first time close-out
    // opens, so it stays the same even if the old visit is edited later.
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
    _ready.dispose();
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

  int? get _readyValue => _ready.intOf('ready_for_market');

  /// What's still missing before close-out counts as done, in words, so
  /// the footer can say what to do rather than just "2 left".
  ///
  /// At least one recommendation is required (20 Nov, Ryan): every visit
  /// should leave the farmer with something to act on. Follow-up is
  /// optional: unanswered means no follow-up, so it's only missing when
  /// Yes is picked without a date.
  List<String> get _missing => [
        if (_readyValue == null) 'pigs ready now',
        if (!_recs.any((c) => c.text.trim().isNotEmpty)) 'a recommendation',
        if (_followUp == true && _by == null) 'a follow-up date',
        if (_reviews?.any((r) => r.outcome == null) ?? false) "last visit's review",
      ];

  void _save() {
    if (_locked || _saved) return;
    if (!_touched && !_ready.anyTyped) return; // opened and left untouched
    VisitService.instance.saveCloseOut(
      _v,
      readyForMarket: _readyValue,
      recommendations: _recs.map((c) => c.text).toList(),
      // Null while still loading: don't save an empty list, or the last
      // visit's recommendations would never be looked up again.
      lastRecsReview: _reviews,
      followUpNeeded: _followUp,
      followUpBy: _followUp == true ? _by : null,
    );
    _saved = true;
  }

  /// The same fields saveCloseOut writes, so the next screen (review)
  /// sees this visit as it now stands without waiting for the write.
  Map<String, dynamic> get _fields => {
        'ready_for_market': _readyValue,
        'recommendations': _recs
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .take(_maxRecs)
            .toList(),
        if (_reviews != null)
          'last_recs_review': _reviews!.map((r) => r.toMap()).toList(),
        'follow_up': {
          'needed': _followUp,
          'by': _followUp == true && _by != null ? Timestamp.fromDate(_by!) : null,
        },
      };

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _by ?? today.add(const Duration(days: 14)),
      // From tomorrow to 3 months out: a follow-up is a near-term plan.
      firstDate: today.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 90)),
    );
    if (d != null) _touch(() => _by = d);
  }

  @override
  Widget build(BuildContext context) {
    final missing = _missing;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: SectionPage(
        section: VisitSection.closeOut,
        locked: _locked,
        footerNote: missing.isEmpty ? 'all done' : 'Still needs ${missing.join(', ')}',
        onSaveAndNext: _locked
            ? null
            : () {
                _touched = true; // pressing the button counts as touching
                _save();
                openNextSection(
                    context, _v.withFields(_fields), VisitSection.closeOut);
              },
        children: [
          SectionCard(children: [
            const SectionTitle('Ready for market now',
                subtitle: 'Pigs the farmer could deliver today'),
            TileGrid(perRow: 2, children: [
              NumberTile(
                label: 'Ready now',
                unit: 'pigs',
                controller: _ready.ctrl['ready_for_market']!,
                focusNode: _ready.focus['ready_for_market']!,
                action: TextInputAction.done,
                onSubmitted: () => _ready.next('ready_for_market'),
                onChanged: () => _touch(() {}),
                enabled: !_locked,
              ),
            ]),
          ]),
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
          SectionCard(children: [
            Row(children: [
              const Expanded(
                child: Text('Follow-up visit needed?',
                    style: TextStyle(fontSize: 13.5, color: AppColors.ink)),
              ),
              AnswerSegment(
                options: _yesNo,
                value: _followUp,
                enabled: !_locked,
                onChanged: (v) => _touch(() => _followUp = v as bool),
              ),
            ]),
            if (_followUp == true) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: _locked ? null : _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _by == null ? AppColors.amber : AppColors.inputBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Text('By', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_by == null ? 'Pick a date' : Formatters.date(_by),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _by == null ? AppColors.amberText : AppColors.ink)),
                    ),
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.muted),
                  ]),
                ),
              ),
            ],
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