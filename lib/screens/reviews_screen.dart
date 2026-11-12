import 'package:flutter/material.dart';

import '../models.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

const _star = Color(0xFFF5A300);

/// Rangée d'étoiles (lecture seule).
class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.size = 16});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i - 0.25
                ? Icons.star_rounded
                : rating >= i - 0.75
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: _star,
          ),
      ],
    );
  }
}

/// Résumé cliquable de la note sur une carte : « ★ 4,3 · 12 avis ».
class RatingLink extends StatelessWidget {
  const RatingLink({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.isPharmacy,
    required this.rating,
    required this.count,
  });

  final String placeId;
  final String placeName;
  final bool isPharmacy;
  final double? rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReviewsScreen(
            placeId: placeId,
            placeName: placeName,
            isPharmacy: isPharmacy,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rating == null ? Icons.star_outline_rounded : Icons.star_rounded,
              size: 18,
              color: _star,
            ),
            const SizedBox(width: 4),
            Text(
              rating == null
                  ? 'Donner un avis'
                  : '${formatRating(rating!)} · $count avis',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Note moyenne, avis des usagers et saisie de son propre avis.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.isPharmacy,
  });

  final String placeId;
  final String placeName;
  final bool isPharmacy;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final _stream = repo.watchReviews(widget.placeId);

  Future<void> _edit(Review? mine) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReviewForm(
        placeId: widget.placeId,
        isPharmacy: widget.isPharmacy,
        mine: mine,
      ),
    );
    if (sent == true && mounted) {
      showMessage(context, 'Merci, votre avis est publié.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: _stream,
      builder: (context, snap) {
        final reviews = snap.data ?? const <Review>[];
        final uid = repo.currentUserId;
        final mine = reviews.where((r) => r.userId == uid).firstOrNull;
        return Scaffold(
          appBar: AppBar(title: const Text('Avis des usagers')),
          body: snap.hasError
              ? const EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Chargement impossible',
                  text: 'Vérifiez votre connexion Internet puis réessayez.',
                )
              : !snap.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _Summary(name: widget.placeName, reviews: reviews),
                    const SizedBox(height: 16),
                    if (reviews.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.rate_review_outlined,
                          title: 'Aucun avis pour le moment',
                          text: 'Soyez la première personne à donner le vôtre.',
                        ),
                      ),
                    for (final r in reviews) ...[
                      ReviewCard(
                        review: r,
                        mine: r.userId == uid,
                        onDelete: repo.isAdmin.value
                            ? () => confirmDeleteReview(context, r)
                            : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: snap.hasData ? () => _edit(mine) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: Icon(
                  mine == null ? Icons.star_rounded : Icons.edit_rounded,
                ),
                label: Text(
                  mine == null ? 'Donner mon avis' : 'Modifier mon avis',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.name, required this.reviews});
  final String name;
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final n = reviews.length;
    final avg = n == 0 ? 0.0 : reviews.fold(0, (a, r) => a + r.rating) / n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            Row(
              children: [
                Column(
                  children: [
                    Text(
                      n == 0 ? '–' : formatRating(avg),
                      style: const TextStyle(
                        fontSize: 44,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Stars(avg, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      '$n avis',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    children: [
                      for (var s = 5; s >= 1; s--)
                        _Bar(
                          stars: s,
                          share: n == 0
                              ? 0
                              : reviews.where((r) => r.rating == s).length / n,
                        ),
                    ],
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

class _Bar extends StatelessWidget {
  const _Bar({required this.stars, required this.share});
  final int stars;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$stars',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 7,
                color: _star,
                backgroundColor: AppColors.neutralBg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Demande confirmation puis supprime un avis (modération administrateur).
Future<void> confirmDeleteReview(BuildContext context, Review r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer cet avis ?'),
      content: const Text('Il sera retiré et la note moyenne recalculée.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.koFg),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await repo.deleteReview(r);
    if (context.mounted) showMessage(context, 'Avis supprimé.');
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Suppression impossible.', error: true);
    }
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.mine = false,
    this.placeName,
    this.onDelete,
  });

  final Review review;
  final bool mine;

  /// Nom du lieu, affiché en tête dans la liste de modération.
  final String? placeName;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = review.authorName.isEmpty ? 'Usager' : review.authorName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (placeName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 8),
                child: Row(
                  children: [
                    Icon(
                      review.isPharmacy
                          ? Icons.local_pharmacy_rounded
                          : Icons.local_gas_station_rounded,
                      size: 16,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        placeName!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.greenDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: mine ? AppColors.okBg : AppColors.neutralBg,
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: mine ? AppColors.okFg : AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine ? '$name (vous)' : name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          Stars(review.rating.toDouble(), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            timeAgo(review.updatedAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Supprimer cet avis',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.koFg,
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            if (review.comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Text(
                  review.comment,
                  style: const TextStyle(height: 1.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Feuille de saisie : étoiles, prénom facultatif, commentaire facultatif.
class _ReviewForm extends StatefulWidget {
  const _ReviewForm({
    required this.placeId,
    required this.isPharmacy,
    this.mine,
  });

  final String placeId;
  final bool isPharmacy;
  final Review? mine;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  static const _labels = [
    '',
    'Très mauvais',
    'Mauvais',
    'Moyen',
    'Bien',
    'Excellent',
  ];

  late int _rating = widget.mine?.rating ?? 0;
  late final _name = TextEditingController(text: widget.mine?.authorName);
  late final _comment = TextEditingController(text: widget.mine?.comment);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await repo.submitReview(
        placeId: widget.placeId,
        isPharmacy: widget.isPharmacy,
        rating: _rating,
        comment: _comment.text.trim(),
        authorName: _name.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(
        context,
        'Envoi impossible. Vérifiez votre connexion puis réessayez.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.mine == null ? 'Votre avis' : 'Modifier votre avis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i sur 5',
                    iconSize: 42,
                    padding: const EdgeInsets.all(4),
                    onPressed: _busy ? null : () => setState(() => _rating = i),
                    icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: _star,
                    ),
                  ),
              ],
            ),
            Text(
              _rating == 0 ? 'Touchez une étoile pour noter' : _labels[_rating],
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Votre prénom (facultatif)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLength: 400,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Votre commentaire (facultatif)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _rating == 0 || _busy ? null : _send,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(_busy ? 'Envoi…' : 'Publier mon avis'),
            ),
          ],
        ),
      ),
    );
  }
}
