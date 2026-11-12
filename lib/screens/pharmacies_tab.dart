import 'package:flutter/material.dart';

import '../models.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'reviews_screen.dart';

class PharmaciesTab extends StatefulWidget {
  const PharmaciesTab({super.key});

  @override
  State<PharmaciesTab> createState() => _PharmaciesTabState();
}

class _PharmaciesTabState extends State<PharmaciesTab> {
  final _stream = repo.watchPharmacies(onDutyOnly: true);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pharmacy>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Chargement impossible',
            text: 'Vérifiez votre connexion Internet puis réessayez.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListenableBuilder(
          listenable: location,
          builder: (context, _) => _buildList(snap.data!),
        );
      },
    );
  }

  Widget _buildList(List<Pharmacy> all) {
    final now = DateTime.now();
    final items =
        all
            .where((p) => p.isOnDutyAt(now))
            .map((p) => (p, location.distanceTo(p.lat, p.lng)))
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));

    return RefreshIndicator(
      onRefresh: location.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: DemoBanner()),
          const SliverToBoxAdapter(child: LocationBanner()),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.local_pharmacy_outlined,
                title: 'Liste de garde non publiée',
                text:
                    'La liste officielle des pharmacies de garde de cette '
                    'semaine n\'est pas encore disponible.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _WeekHeader(
                  count: items.length,
                  start: items.first.$1.dutyStart!,
                  end: items.first.$1.dutyEnd!,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverCardGrid(
                itemCount: items.length,
                itemBuilder: (context, i) => _PharmacyCard(
                  pharmacy: items[i].$1,
                  distance: items[i].$2,
                  nearest: i == 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.count,
    required this.start,
    required this.end,
  });

  final int count;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.green, AppColors.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garde ${formatPeriod(start, end)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count pharmacie${count > 1 ? 's' : ''} · liste officielle',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  const _PharmacyCard({
    required this.pharmacy,
    required this.distance,
    required this.nearest,
  });

  final Pharmacy pharmacy;
  final double distance;
  final bool nearest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBadge(
                      icon: Icons.local_pharmacy_rounded,
                      bg: AppColors.okBg,
                      fg: AppColors.okFg,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pharmacy.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            placeLine(
                              pharmacy.address,
                              pharmacy.city,
                              pharmacy.department,
                            ),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RatingLink(
                            placeId: pharmacy.id,
                            placeName: pharmacy.name,
                            isPharmacy: true,
                            rating: pharmacy.rating,
                            count: pharmacy.ratingCount,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    DistanceLabel(distance),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Pill(
                      label: 'De garde',
                      bg: AppColors.okBg,
                      fg: AppColors.okFg,
                      icon: Icons.nightlight_round,
                    ),
                    if (nearest)
                      const Pill(
                        label: 'La plus proche',
                        bg: AppColors.waitBg,
                        fg: AppColors.waitFg,
                        icon: Icons.bolt_rounded,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DirectionsButton(lat: pharmacy.lat, lng: pharmacy.lng),
                ),
                if (pharmacy.phone.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => callPhone(pharmacy.phone),
                      icon: const Icon(Icons.call_rounded, size: 20),
                      label: const Text('Appeler'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
