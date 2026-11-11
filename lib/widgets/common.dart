import 'package:flutter/material.dart';

import '../models.dart';
import '../services/location_service.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../utils.dart';

/// Pastille colorée (statut, période…).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  factory Pill.fuel(FuelStatus s) => switch (s) {
    FuelStatus.available => const Pill(
      label: 'Essence disponible',
      bg: AppColors.okBg,
      fg: AppColors.okFg,
      icon: Icons.check_circle_rounded,
    ),
    FuelStatus.unavailable => const Pill(
      label: 'Pas d\'essence',
      bg: AppColors.koBg,
      fg: AppColors.koFg,
      icon: Icons.cancel_rounded,
    ),
    FuelStatus.unknown => const Pill(
      label: 'Non renseigné',
      bg: AppColors.neutralBg,
      fg: AppColors.muted,
      icon: Icons.help_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carré arrondi contenant une icône, en tête de carte.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: fg, size: 24),
    );
  }
}

/// Distance mise en avant à droite d'une carte.
class DistanceLabel extends StatelessWidget {
  const DistanceLabel(this.meters, {super.key});
  final double meters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatDistance(meters),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        Text(
          location.hasFix ? 'de vous' : 'de Cotonou',
          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.neutralBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Bandeau affiché quand la position de l'utilisateur est indisponible.
class LocationBanner extends StatelessWidget {
  const LocationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: location,
      builder: (context, _) {
        if (location.state == LocationState.ready ||
            location.state == LocationState.loading) {
          return const SizedBox.shrink();
        }
        final off = location.state == LocationState.serviceOff;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: BoxDecoration(
            color: AppColors.waitBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_off_rounded, color: AppColors.waitFg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  off
                      ? 'GPS désactivé. Les distances sont calculées depuis Cotonou.'
                      : 'Position non autorisée. Les distances sont calculées depuis Cotonou.',
                  style: const TextStyle(
                    color: AppColors.waitFg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await location.refresh();
                  if (!location.hasFix) await location.openSettings();
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.waitFg),
                child: const Text('Activer'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bandeau discret signalant que l'application tourne sans Firebase.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!repo.isDemo) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_rounded, color: AppColors.yellow, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode démo : données fictives, Firebase non configuré.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton « Itinéraire » ouvrant Google Maps.
class DirectionsButton extends StatelessWidget {
  const DirectionsButton({super.key, required this.lat, required this.lng});
  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () async {
        final ok = await openDirections(lat, lng);
        if (!ok && context.mounted) {
          showMessage(
            context,
            'Impossible d\'ouvrir Google Maps.',
            error: true,
          );
        }
      },
      icon: const Icon(Icons.directions_rounded, size: 20),
      label: const Text('Itinéraire'),
    );
  }
}
