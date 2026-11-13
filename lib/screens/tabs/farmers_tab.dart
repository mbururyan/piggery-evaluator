import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/farmer.dart';
import '../../models/farmer_sort.dart';
import '../../services/farmer_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_header.dart';
import '../farmer_detail_screen.dart';
import '../register_farmer_screen.dart';

class FarmersTab extends StatefulWidget {
  const FarmersTab({super.key});

  @override
  State<FarmersTab> createState() => _FarmersTabState();
}

class _FarmersTabState extends State<FarmersTab> {
  static const _sortPrefKey = 'farmers_sort';

  final _searchCtrl = TextEditingController();
  String _query = '';
  FarmerSort _sort = FarmerSort.newest;

  // Made once, not inside build(): a new stream on every rebuild would
  // drop and re-open the Firestore listener each time a key is typed.
  late final Stream<List<Farmer>> _stream = FarmerService.instance.myFarmers();

  @override
  void initState() {
    super.initState();
    _loadSort();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// The sort choice is remembered on the phone between launches.
  Future<void> _loadSort() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = FarmerSort.fromKey(prefs.getString(_sortPrefKey));
    if (mounted) setState(() => _sort = saved);
  }

  Future<void> _setSort(FarmerSort s) async {
    setState(() => _sort = s);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortPrefKey, s.key);
  }

  void _openRegister() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterFarmerScreen()));

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort farmers by',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final s in FarmerSort.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: s == _sort ? AppColors.red : AppColors.ink,
                      fontWeight:
                          s == _sort ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  subtitle: s.note == null
                      ? null
                      : Text(s.note!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                  trailing: s == _sort
                      ? const Icon(Icons.check, color: AppColors.red, size: 20)
                      : null,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _setSort(s);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Farmer>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data;

        // Copy before sorting: never reorder the list the stream handed us.
        final shown = (all ?? const <Farmer>[])
            .where((f) => f.matches(_query))
            .toList();
        _sort.apply(shown);

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabHeader(
                title: 'My farmers',
                count: all?.length,
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
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name, PF, phone or ID…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _query.isEmpty
                        ? '${shown.length} farmers'
                        : '${shown.length} of ${all?.length ?? 0}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const Spacer(),
                  _SortChip(label: _sort.label, onTap: _showSortSheet),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: _body(snap, all, shown)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<List<Farmer>> snap, List<Farmer>? all,
      List<Farmer> shown) {
    if (snap.hasError) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load farmers',
        message: 'Check your connection and reopen this tab.',
      );
    }
    if (all == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (all.isEmpty) {
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
        message: 'Nothing matches "${_query.trim()}".',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: shown.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) => _FarmerCard(farmer: shown[i]),
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
              const Icon(Icons.arrow_drop_down,
                  size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  const _FarmerCard({required this.farmer});

  final Farmer farmer;

  /// The second line under the location: visit info once Phase 3 writes
  /// summaries; until then, who registered app farmers and when.
  String get _activity {
    final s = farmer.summary;
    if (s?.lastVisitDate != null) {
      final sows = s!.sows == null ? '' : ' · ${s.sows} sows';
      return 'last visit ${Formatters.relativeDate(s.lastVisitDate)}$sows';
    }
    if (farmer.source == 'app') {
      return 'registered ${Formatters.relativeDate(farmer.registeredAt)}'
          ' · by ${farmer.assignedEoName}';
    }
    return 'not visited yet';
  }

  @override
  Widget build(BuildContext context) {
    final pending = farmer.isPendingPf;
    final radius = BorderRadius.circular(14);

    // Shadow on the outside, clipping on the inside. Flutter refuses a
    // rounded box with a border on one side only, so the amber edge is
    // its own 3 px strip, and the rounded clip trims its corners.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppShadows.card),
      child: Material(
        color: AppColors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FarmerDetailScreen(farmerId: farmer.id))),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amber edge = still waiting for the office to assign a PF.
                if (pending) Container(width: 3, color: AppColors.amber),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(farmer.title,
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink)),
                              const SizedBox(height: 3),
                              Text(
                                '${farmer.location.short} · '
                                '${Formatters.displayPhone(farmer.mobile)}',
                                style: const TextStyle(
                                    fontSize: 11.5, color: AppColors.muted),
                              ),
                              const SizedBox(height: 1),
                              Text(_activity,
                                  style: const TextStyle(
                                      fontSize: 11.5, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        if (farmer.hasPendingWrites)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Tooltip(
                              message: 'Not synced yet',
                              child: Icon(Icons.cloud_upload_outlined,
                                  size: 16, color: AppColors.amber),
                            ),
                          ),
                        if (pending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amberTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('PF pending',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.amberText)),
                          ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}