import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/reviews_screen.dart';
import '../services/repository.dart';
import '../widgets/common.dart';

enum _Filter { all, low, stations, pharmacies }

/// Modération : derniers avis des usagers, tous lieux confondus, avec
/// recherche, filtres et suppression.
class ReviewsAdminTab extends StatefulWidget {
  const ReviewsAdminTab({super.key});

  @override
  State<ReviewsAdminTab> createState() => _ReviewsAdminTabState();
}

class _ReviewsAdminTabState extends State<ReviewsAdminTab> {
  final _reviews = repo.watchAllReviews();
  final _stations = repo.watchStations();
  final _pharmacies = repo.watchPharmacies();
  _Filter _filter = _Filter.all;
  String _query = '';

  bool _keep(Review r, String placeName) {
    final byFilter = switch (_filter) {
      _Filter.all => true,
      _Filter.low => r.rating <= 2,
      _Filter.stations => !r.isPharmacy,
      _Filter.pharmacies => r.isPharmacy,
    };
    return byFilter &&
        '$placeName ${r.authorName} ${r.comment}'.toLowerCase().contains(
          _query,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Les noms des lieux viennent des annuaires (l'avis ne porte que l'ID).
    return StreamBuilder<List<Station>>(
      stream: _stations,
      builder: (context, stations) => StreamBuilder<List<Pharmacy>>(
        stream: _pharmacies,
        builder: (context, pharmacies) {
          final names = {
            for (final s in stations.data ?? const <Station>[]) s.id: s.name,
            for (final p in pharmacies.data ?? const <Pharmacy>[]) p.id: p.name,
          };
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _query = v.toLowerCase().trim()),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un lieu, un auteur, un mot',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _chip('Tous', _Filter.all),
                    _chip('Notes basses', _Filter.low),
                    _chip('Stations', _Filter.stations),
                    _chip('Pharmacies', _Filter.pharmacies),
                  ],
                ),
              ),
              Expanded(child: _list(names)),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, _Filter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: selected ? Colors.white : null,
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _list(Map<String, String> names) {
    return StreamBuilder<List<Review>>(
      stream: _reviews,
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
        String nameOf(Review r) => names[r.placeId] ?? 'Lieu supprimé';
        final items = snap.data!.where((r) => _keep(r, nameOf(r))).toList();
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.rate_review_outlined,
            title: 'Aucun avis',
            text: snap.data!.isEmpty
                ? 'Les avis des usagers apparaîtront ici.'
                : 'Aucun avis ne correspond à ce filtre.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => ReviewCard(
            review: items[i],
            placeName: nameOf(items[i]),
            onDelete: () => confirmDeleteReview(context, items[i]),
          ),
        );
      },
    );
  }
}
