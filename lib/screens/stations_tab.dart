import 'package:flutter/material.dart';

import '../models.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'report_screen.dart';
import 'reviews_screen.dart';

class StationsTab extends StatefulWidget {
  const StationsTab({super.key});

  @override
  State<StationsTab> createState() => _StationsTabState();
}

class _StationsTabState extends State<StationsTab> {
  final _stream = repo.watchStations();
  bool _onlyWithFuel = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Station>>(
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

  Widget _buildList(List<Station> all) {
    final withFuel = all.where((s) => s.status == FuelStatus.available);
    final items =
        (_onlyWithFuel ? withFuel : all)
            .map((s) => (s, location.distanceTo(s.lat, s.lng)))
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));

    return RefreshIndicator(
      onRefresh: location.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: DemoBanner()),
          const SliverToBoxAdapter(child: LocationBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  _filter('Avec essence · ${withFuel.length}', true),
                  const SizedBox(width: 8),
                  _filter('Toutes · ${all.length}', false),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.local_gas_station_outlined,
                title: _onlyWithFuel
                    ? 'Aucune station avec essence'
                    : 'Aucune station enregistrée',
                text: _onlyWithFuel
                    ? 'Aucune disponibilité n\'est certifiée pour le moment. '
                          'Vous êtes devant une station servie ? Signalez-la.'
                    : 'Les stations apparaîtront ici dès leur ajout.',
                action: _onlyWithFuel && all.isNotEmpty
                    ? OutlinedButton(
                        onPressed: () => setState(() => _onlyWithFuel = false),
                        child: const Text('Voir toutes les stations'),
                      )
                    : null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverCardGrid(
                itemCount: items.length,
                itemBuilder: (context, i) => _StationCard(
                  station: items[i].$1,
                  distance: items[i].$2,
                  nearest: i == 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filter(String label, bool value) {
    final selected = _onlyWithFuel == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
        color: selected ? Colors.white : AppColors.ink,
      ),
      onSelected: (_) => setState(() => _onlyWithFuel = value),
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.distance,
    required this.nearest,
  });

  final Station station;
  final double distance;
  final bool nearest;

  @override
  Widget build(BuildContext context) {
    final ok = station.status == FuelStatus.available;
    final ko = station.status == FuelStatus.unavailable;
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
                    IconBadge(
                      icon: Icons.local_gas_station_rounded,
                      bg: ok
                          ? AppColors.okBg
                          : ko
                          ? AppColors.koBg
                          : AppColors.neutralBg,
                      fg: ok
                          ? AppColors.okFg
                          : ko
                          ? AppColors.koFg
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            placeLine(
                              station.address,
                              station.city,
                              station.department,
                            ),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RatingLink(
                            placeId: station.id,
                            placeName: station.name,
                            isPharmacy: false,
                            rating: station.rating,
                            count: station.ratingCount,
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
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pill.fuel(station.status),
                    if (nearest)
                      const Pill(
                        label: 'La plus proche',
                        bg: AppColors.waitBg,
                        fg: AppColors.waitFg,
                        icon: Icons.bolt_rounded,
                      ),
                    if (station.statusUpdatedAt != null)
                      Text(
                        'Certifié ${timeAgo(station.statusUpdatedAt!)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DirectionsButton(lat: station.lat, lng: station.lng),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        openPage(context, ReportScreen(station: station)),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text('Signaler'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
