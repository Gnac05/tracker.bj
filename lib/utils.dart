import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Principales villes du Bénin, proposées dans les formulaires.
const beninCities = [
  'Cotonou',
  'Abomey-Calavi',
  'Porto-Novo',
  'Sèmè-Kpodji',
  'Ouidah',
  'Allada',
  'Bohicon',
  'Abomey',
  'Lokossa',
  'Comé',
  'Dassa-Zoumè',
  'Savalou',
  'Parakou',
  'Djougou',
  'Natitingou',
  'Kandi',
  'Malanville',
  'Pobè',
  'Kétou',
  'Autre',
];

/// Limites géographiques approximatives du Bénin (validation des saisies).
bool isInBenin(double lat, double lng) =>
    lat >= 6.0 && lat <= 12.6 && lng >= 0.7 && lng <= 3.9;

String formatDistance(double meters) {
  if (meters < 950) return '${(meters / 10).round() * 10} m';
  final km = meters / 1000;
  return km < 10
      ? '${km.toStringAsFixed(1).replaceAll('.', ',')} km'
      : '${km.round()} km';
}

/// « à l'instant », « il y a 12 min », « il y a 3 h », « hier », « le 4 nov. ».
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'à l\'instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} jours';
  return 'le ${DateFormat('d MMM', 'fr').format(d)}';
}

String formatPeriod(DateTime start, DateTime endExclusive) {
  final end = endExclusive.subtract(const Duration(minutes: 1));
  final f = DateFormat('d MMM', 'fr');
  return 'du ${f.format(start)} au ${f.format(end)}';
}

/// Semaine en cours, du lundi 00h00 au lundi suivant 00h00.
DateTimeRange currentWeek() {
  final now = DateTime.now();
  final monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  return DateTimeRange(start: monday, end: monday.add(const Duration(days: 7)));
}

/// Ouvre Google Maps avec l'itinéraire vers la destination.
Future<bool> openDirections(double lat, double lng) {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> callPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  return launchUrl(Uri(scheme: 'tel', path: digits));
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFB80D24) : null,
      ),
    );
}
