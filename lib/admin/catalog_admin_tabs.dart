import 'package:flutter/material.dart';

import '../models.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'place_form_screen.dart';

/// Annuaire des stations (ajout, modification, suppression).
class StationsAdminTab extends StatefulWidget {
  const StationsAdminTab({super.key});

  @override
  State<StationsAdminTab> createState() => _StationsAdminTabState();
}

class _StationsAdminTabState extends State<StationsAdminTab> {
  final _stream = repo.watchStations();

  @override
  Widget build(BuildContext context) {
    return _Catalog<Station>(
      stream: _stream,
      addLabel: 'Ajouter une station',
      emptyTitle: 'Aucune station',
      searchText: (s) => '${s.name} ${s.address} ${s.city}',
      onAdd: () => _open(context, const PlaceFormScreen(isPharmacy: false)),
      tile: (s) => _CatalogTile(
        icon: Icons.local_gas_station_rounded,
        title: s.name,
        subtitle: '${s.address} · ${s.city}',
        trailing: Pill.fuel(s.status),
        onTap: () =>
            _open(context, PlaceFormScreen(isPharmacy: false, station: s)),
      ),
    );
  }
}

/// Annuaire des pharmacies (ajout, modification, suppression).
class PharmaciesAdminTab extends StatefulWidget {
  const PharmaciesAdminTab({super.key});

  @override
  State<PharmaciesAdminTab> createState() => _PharmaciesAdminTabState();
}

class _PharmaciesAdminTabState extends State<PharmaciesAdminTab> {
  final _stream = repo.watchPharmacies();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _Catalog<Pharmacy>(
      stream: _stream,
      addLabel: 'Ajouter une pharmacie',
      emptyTitle: 'Aucune pharmacie',
      searchText: (p) => '${p.name} ${p.address} ${p.city}',
      onAdd: () => _open(context, const PlaceFormScreen(isPharmacy: true)),
      tile: (p) => _CatalogTile(
        icon: Icons.local_pharmacy_rounded,
        title: p.name,
        subtitle: '${p.address} · ${p.city}',
        trailing: p.isOnDutyAt(now)
            ? const Pill(
                label: 'De garde',
                bg: AppColors.okBg,
                fg: AppColors.okFg,
              )
            : null,
        onTap: () =>
            _open(context, PlaceFormScreen(isPharmacy: true, pharmacy: p)),
      ),
    );
  }
}

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

class _Catalog<T> extends StatefulWidget {
  const _Catalog({
    required this.stream,
    required this.addLabel,
    required this.emptyTitle,
    required this.searchText,
    required this.onAdd,
    required this.tile,
  });

  final Stream<List<T>> stream;
  final String addLabel;
  final String emptyTitle;
  final String Function(T) searchText;
  final VoidCallback onAdd;
  final Widget Function(T) tile;

  @override
  State<_Catalog<T>> createState() => _CatalogState<T>();
}

class _CatalogState<T> extends State<_Catalog<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAdd,
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(widget.addLabel),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
              decoration: const InputDecoration(
                hintText: 'Rechercher',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<T>>(
              stream: widget.stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Chargement impossible',
                    text: 'Vérifiez votre connexion Internet.',
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items =
                    snap.data!
                        .where(
                          (e) => widget
                              .searchText(e)
                              .toLowerCase()
                              .contains(_query),
                        )
                        .toList()
                      ..sort(
                        (a, b) => widget
                            .searchText(a)
                            .toLowerCase()
                            .compareTo(widget.searchText(b).toLowerCase()),
                      );
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: widget.emptyTitle,
                    text: _query.isEmpty
                        ? 'Utilisez le bouton ci-dessous pour en ajouter.'
                        : 'Aucun résultat pour cette recherche.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => widget.tile(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconBadge(icon: icon, bg: AppColors.neutralBg, fg: AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
