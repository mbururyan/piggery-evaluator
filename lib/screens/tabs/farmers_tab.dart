import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/farmer.dart';
import '../../models/farmer_sort.dart';
import '../../services/auth_service.dart';
import '../../services/farmer_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/farmer_card.dart';
import '../../widgets/tab_header.dart';
import '../register_farmer_screen.dart';

/// "My farmers" (the EO's own, cached on the phone, works offline) or
/// "All farmers" (everyone's, fetched from the server a page at a time).
enum FarmerView { mine, all }

class FarmersTab extends StatefulWidget {
  const FarmersTab({super.key});

  @override
  State<FarmersTab> createState() => _FarmersTabState();
}

class _FarmersTabState extends State<FarmersTab> {
  static const _sortPrefKey = 'farmers_sort';
  static const _viewPrefKey = 'farmers_view';

  final _searchCtrl = TextEditingController();
  String _query = '';

  /// What All farmers actually searches for. Lags _query by 400 ms, so the
  /// server is asked once the EO pauses, not on every keystroke.
  String _serverQuery = '';
  Timer? _debounce;

  FarmerSort _sort = FarmerSort.newest;
  FarmerView _view = FarmerView.mine;

  // Made once, not inside build(): a new stream on every rebuild would
  // drop and re-open the Firestore listener each time a key is typed.
  late final Stream<List<Farmer>> _mine = FarmerService.instance.myFarmers();
  final String? _uid = AuthService.instance.currentUser?.uid;

  /// Only Newest and A–Z work across all farmers (the visit-based sorts
  /// need every farmer on the phone, which All deliberately avoids). The
  /// saved choice is kept for when the EO switches back to My farmers.
  FarmerSort get _effectiveSort =>
      _view == FarmerView.all && !_worksForAll(_sort) ? FarmerSort.az : _sort;

  static bool _worksForAll(FarmerSort s) =>
      s == FarmerSort.newest || s == FarmerSort.az;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// View and sort are remembered on the phone between launches.
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sort = FarmerSort.fromKey(prefs.getString(_sortPrefKey));
      _view = prefs.getString(_viewPrefKey) == 'all'
          ? FarmerView.all
          : FarmerView.mine;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortPrefKey, _sort.key);
    await prefs.setString(_viewPrefKey, _view.name);
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _serverQuery = v.trim());
    });
  }

  void _openRegister() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterFarmerScreen()));

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      // StatefulBuilder: the sheet redraws itself when the view toggle
      // changes, so the greyed-out sorts update while it's still open.
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          void pickView(FarmerView v) {
            setState(() => _view = v);
            setSheet(() {});
            _save();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Show',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _Segment(
                      label: 'My farmers',
                      selected: _view == FarmerView.mine,
                      onTap: () => pickView(FarmerView.mine),
                    ),
                    const SizedBox(width: 8),
                    _Segment(
                      label: 'All farmers',
                      selected: _view == FarmerView.all,
                      onTap: () => pickView(FarmerView.all),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Sort by',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  for (final s in FarmerSort.values)
                    _sortTile(sheetCtx, s),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sortTile(BuildContext sheetCtx, FarmerSort s) {
    final enabled = _view == FarmerView.mine || _worksForAll(s);
    final selected = s == _effectiveSort;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      enabled: enabled,
      title: Text(
        s.label,
        style: TextStyle(
          fontSize: 14,
          color: !enabled
              ? AppColors.inputBorder
              : (selected ? AppColors.red : AppColors.ink),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: !enabled
          ? const Text('My farmers only',
              style: TextStyle(fontSize: 11, color: AppColors.inputBorder))
          : (s.note == null
              ? null
              : Text(s.note!,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted))),
      trailing: selected && enabled
          ? const Icon(Icons.check, color: AppColors.red, size: 20)
          : null,
      onTap: () {
        Navigator.of(sheetCtx).pop();
        setState(() => _sort = s);
        _save();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _view == FarmerView.all;
    final chipLabel = all ? 'All · ${_effectiveSort.label}' : _effectiveSort.label;

    Widget header({int? count, String? countLine}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabHeader(
              title: all ? 'All farmers' : 'My farmers',
              count: count,
              action: IconButton(
                tooltip: 'Register a new farmer',
                icon: const Icon(Icons.person_add_alt_1_outlined,
                    color: AppColors.red),
                onPressed: _openRegister,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: all
                    ? 'Search all: name, PF, phone or ID…'
                    : 'Search name, PF, phone or ID…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onQueryChanged('');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(countLine ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              _SortChip(label: chipLabel, onTap: _showOptionsSheet),
            ]),
            const SizedBox(height: 10),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: all
          ? _AllFarmersBody(
              // Keyed on sort + query: a new search or order starts fresh
              // from page one instead of mixing with the old results.
              key: ValueKey('${_effectiveSort.key}|$_serverQuery'),
              newestFirst: _effectiveSort == FarmerSort.newest,
              query: _serverQuery,
              uid: _uid,
              header: header,
              onShowMine: () {
                setState(() => _view = FarmerView.mine);
                _save();
              },
            )
          : StreamBuilder<List<Farmer>>(
              stream: _mine,
              builder: (context, snap) {
                final list = snap.data;
                final shown = (list ?? const <Farmer>[])
                    .where((f) => f.matches(_query))
                    .toList();
                _effectiveSort.apply(shown);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header(
                      count: list?.length,
                      countLine: _query.isEmpty
                          ? '${shown.length} farmers'
                          : '${shown.length} of ${list?.length ?? 0}',
                    ),
                    Expanded(child: _mineBody(snap, list, shown)),
                  ],
                );
              },
            ),
    );
  }

  Widget _mineBody(AsyncSnapshot<List<Farmer>> snap, List<Farmer>? list,
      List<Farmer> shown) {
    if (snap.hasError) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load farmers',
        message: 'Check your connection and reopen this tab.',
      );
    }
    if (list == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        message:
            'Your assigned farmers will appear here. Register one with the + above.',
      );
    }
    if (shown.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'None of your farmers match "${_query.trim()}". '
            'Try All farmers in the sort menu.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: shown.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) =>
          FarmerCard(farmer: shown[i], currentUid: _uid),
    );
  }
}

/// All farmers: a server list, 30 at a time, or server search results.
class _AllFarmersBody extends StatefulWidget {
  const _AllFarmersBody({
    super.key,
    required this.newestFirst,
    required this.query,
    required this.uid,
    required this.header,
    required this.onShowMine,
  });

  final bool newestFirst;
  final String query;
  final String? uid;
  final Widget Function({int? count, String? countLine}) header;
  final VoidCallback onShowMine;

  @override
  State<_AllFarmersBody> createState() => _AllFarmersBodyState();
}

class _AllFarmersBodyState extends State<_AllFarmersBody> {
  final _scroll = ScrollController();
  final _items = <Farmer>[];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _loading = false;
  bool _hasMore = true;

  /// 'offline' or 'index' or null.
  String? _problem;
  int? _total;

  bool get _searching => widget.query.length >= 2;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Fetch the next page when the EO is ~2 screens from the bottom.
      if (!_searching &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        _loadMore();
      }
    });
    if (!_searching) {
      FarmerService.instance.countAll().then((n) {
        if (mounted) setState(() => _total = n);
      });
    }
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    if (widget.query.isNotEmpty && !_searching) return; // 1 character: wait
    setState(() {
      _loading = true;
      _problem = null;
    });
    try {
      if (_searching) {
        final found = await FarmerService.instance.searchAll(widget.query);
        _items
          ..clear()
          ..addAll(found);
        _hasMore = false; // search shows the top 30; typing more narrows it
      } else {
        final page = await FarmerService.instance
            .allPage(newestFirst: widget.newestFirst, startAfter: _last);
        _items.addAll(page.farmers);
        _last = page.last;
        _hasMore = page.hasMore;
      }
    } on FirebaseException catch (e) {
      // A missing index shows up as failed-precondition, with a link in
      // the message that creates it. Print it so it can be clicked from
      // the debug console.
      if (e.code == 'failed-precondition') {
        debugPrint('FIRESTORE INDEX NEEDED: ${e.message}');
        _problem = 'index';
      } else {
        _problem = 'offline';
      }
    } catch (_) {
      _problem = 'offline'; // timeouts land here
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final countLine = _searching
        ? (_loading ? 'Searching…' : '${_items.length} found${_items.length == FarmerService.pageSize ? ' (first 30, type more to narrow)' : ''}')
        : 'Needs signal · ${widget.newestFirst ? 'newest first' : 'A–Z'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.header(count: _searching ? null : _total, countLine: countLine),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_items.isEmpty && _problem == 'offline') {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'All farmers needs signal',
            message: 'Your own farmers are saved on this phone.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: widget.onShowMine,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red, width: 0.8),
            ),
            child: const Text('Show my farmers'),
          ),
        ]),
      );
    }
    if (_items.isEmpty && _problem == 'index') {
      return const EmptyState(
        icon: Icons.build_outlined,
        title: 'Search is being set up',
        message: 'A one-time database index is needed. '
            'See the debug console for the link, then try again in a few minutes.',
      );
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (widget.query.length == 1) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Keep typing',
        message: 'Type at least 2 characters to search all farmers.',
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: _searching
            ? 'No farmer matches "${widget.query}".'
            : 'No farmers yet.',
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 18),
      // One extra row at the end for "loading more" / "couldn't load more".
      itemCount: _items.length + (_hasMore || _problem != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) {
        if (i < _items.length) {
          return FarmerCard(
              farmer: _items[i], currentUid: widget.uid, showEo: true);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: _problem != null
                ? TextButton(
                    onPressed: _loadMore,
                    child: const Text('Couldn\'t load more · tap to retry'))
                : const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.red : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: selected ? AppColors.red : AppColors.inputBorder, width: 0.8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const StadiumBorder(
          side: BorderSide(color: AppColors.inputBorder, width: 0.8)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort, size: 15, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink)),
              const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}