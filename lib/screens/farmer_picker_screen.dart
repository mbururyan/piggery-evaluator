import 'package:flutter/material.dart';

import '../models/farmer.dart';
import '../models/farmer_sort.dart';
import '../services/auth_service.dart';
import '../services/farmer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/farmer_card.dart';
import 'visit_setup_screen.dart';

/// "Who are you visiting?" Opened from Home's Start a farm visit card.
///
/// The EO's own farmers only, newest registered first (Ryan, 17 Nov): the
/// farmer an EO just registered is usually the one they're about to visit,
/// so it's the first card, no scrolling. Works offline from the cache.
/// To visit a colleague's farmer, go through Farmers → All farmers and
/// tap Start a visit on their page.
class FarmerPickerScreen extends StatefulWidget {
  const FarmerPickerScreen({super.key});

  @override
  State<FarmerPickerScreen> createState() => _FarmerPickerScreenState();
}

class _FarmerPickerScreenState extends State<FarmerPickerScreen> {
  String _query = '';
  late final Stream<List<Farmer>> _stream = FarmerService.instance.myFarmers();
  final _uid = AuthService.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.ink,
        title: const Text('Pick a farmer',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search your farmers…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your farmers · newest first',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<Farmer>>(
                  stream: _stream,
                  builder: (context, snap) {
                    final all = snap.data;
                    if (all == null) {
                      return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4));
                    }
                    final shown = all.where((f) => f.matches(_query)).toList();
                    FarmerSort.newest.apply(shown);
                    if (shown.isEmpty) {
                      return const EmptyState(
                        icon: Icons.search_off,
                        title: 'No matches',
                        message:
                            "To visit a colleague's farmer, find them in Farmers → All farmers.",
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 18),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, i) => _Pickable(
                        farmer: shown[i],
                        uid: _uid,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A FarmerCard whose tap starts a visit instead of opening the farmer.
class _Pickable extends StatelessWidget {
  const _Pickable({required this.farmer, required this.uid});
  final Farmer farmer;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      FarmerCard(farmer: farmer, currentUid: uid),
      // A transparent layer over the card takes the tap, so the card
      // itself needs no "picker mode".
      Positioned.fill(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => VisitSetupScreen(farmerId: farmer.id))),
          ),
        ),
      ),
    ]);
  }
}