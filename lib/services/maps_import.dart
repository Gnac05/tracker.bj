import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../utils.dart';

/// Données d'un lieu récupérées depuis Google Maps.
class MapsPlace {
  String? name;

  /// Quartier ou repère.
  String? address;
  String? city;
  String? department;
  double? lat;
  double? lng;

  /// Vrai quand la position ne vient pas des coordonnées exactes du lieu
  /// (centre de la carte ou recherche par nom) : à vérifier par l'admin.
  bool approximate = false;

  bool get hasPosition => lat != null && lng != null;
}

class MapsImportException implements Exception {
  MapsImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

final _coords = RegExp(r'(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})');
final _url = RegExp(r'https?://\S+');

/// Analyse hors ligne d'un texte copié depuis Google Maps : lien complet,
/// texte de partage (« Nom du lieu » suivi du lien) ou coordonnées brutes
/// (« 6.3654, 2.4183 »).
MapsPlace parseMapsText(String text) {
  final place = MapsPlace();
  final link = _url.firstMatch(text);
  if (link == null) {
    final m = _coords.firstMatch(text);
    if (m != null) _setCoords(place, m);
    return place;
  }
  parseMapsUrl(Uri.parse(link.group(0)!), into: place);
  // Le partage depuis l'application place le nom du lieu avant le lien.
  final before = text.substring(0, link.start).trim().split('\n').first.trim();
  if (before.isNotEmpty && !_coords.hasMatch(before)) place.name = before;
  return place;
}

void _setCoords(MapsPlace place, RegExpMatch m) {
  place.lat = double.parse(m.group(1)!);
  place.lng = double.parse(m.group(2)!);
}

/// Extrait le nom, l'adresse et la position d'une URL Google Maps.
MapsPlace parseMapsUrl(Uri uri, {MapsPlace? into}) {
  final place = into ?? MapsPlace();
  final full = Uri.decodeFull(uri.toString());

  // 1. Coordonnées exactes du lieu : « !3d<lat>!4d<lng> ».
  final exact = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)')
      .allMatches(full)
      .lastOrNull;
  if (exact != null) {
    _setCoords(place, exact);
  } else {
    // 2. Coordonnées passées en paramètre (épingle déposée, itinéraire…).
    for (final key in ['q', 'query', 'destination', 'll', 'center']) {
      final m = _coords.firstMatch(uri.queryParameters[key] ?? '');
      if (m != null) {
        _setCoords(place, m);
        break;
      }
    }
  }
  // 3. À défaut, le centre de la carte « @lat,lng » : approximatif.
  if (!place.hasPosition) {
    final at = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(full);
    if (at != null) {
      _setCoords(place, at);
      place.approximate = true;
    }
  }

  // Libellé : « /maps/place/Nom, Adresse, Ville/ » ou paramètre « q ».
  final segs = uri.pathSegments;
  final i = segs.indexOf('place');
  var label = i >= 0 && i + 1 < segs.length ? segs[i + 1] : null;
  label ??= uri.queryParameters['q'] ?? uri.queryParameters['query'];
  if (label != null) {
    label = label.replaceAll('+', ' ').trim();
    if (label.isNotEmpty && !_coords.hasMatch(label) && !label.contains('°')) {
      final parts = label.split(',').map((p) => p.trim()).toList();
      place.name = parts.first;
      for (final p in parts.skip(1)) {
        final city = matchCity(p);
        if (city != null) {
          place.city ??= city;
        } else if (matchDepartment(p) == null &&
            normalizePlace(p) != 'benin' &&
            p.isNotEmpty) {
          place.address ??= p;
        }
      }
    }
  }
  return place;
}

bool _isShortLink(Uri u) =>
    u.host == 'maps.app.goo.gl' || u.host == 'goo.gl' || u.host == 'g.co';

/// Suit les redirections d'un lien court jusqu'à l'URL Google Maps complète.
Future<Uri> _resolve(Uri uri) async {
  final client = http.Client();
  try {
    var current = uri;
    for (var i = 0; i < 6; i++) {
      final req = http.Request('GET', current)..followRedirects = false;
      final res = await client.send(req).timeout(const Duration(seconds: 15));
      await res.stream.drain<void>();
      final next = res.headers['location'];
      if (!res.isRedirect || next == null) break;
      current = current.resolve(next);
      if (!_isShortLink(current) && current.host.contains('google.')) {
        final parsed = parseMapsUrl(current);
        if (parsed.hasPosition || parsed.name != null) break;
      }
    }
    return current;
  } finally {
    client.close();
  }
}

/// Importe un lieu à partir d'un texte copié depuis Google Maps, puis
/// complète quartier, ville et département par géocodage inverse.
Future<MapsPlace> importFromGoogleMaps(String text) async {
  var place = parseMapsText(text);
  final link = _url.firstMatch(text);

  if (link != null) {
    final uri = Uri.parse(link.group(0)!);
    if (_isShortLink(uri) && !place.hasPosition) {
      final sharedName = place.name;
      try {
        place = parseMapsUrl(await _resolve(uri));
      } catch (_) {
        throw MapsImportException(
          kIsWeb
              ? 'Le navigateur ne peut pas ouvrir les liens courts. Collez '
                    'le lien complet ou les coordonnées du lieu.'
              : 'Lien illisible. Vérifiez votre connexion Internet.',
        );
      }
      place.name = sharedName ?? place.name;
    }
  }

  // Lien sans coordonnées : recherche par nom, donc position approximative.
  if (!place.hasPosition && place.name != null) {
    final query = [
      place.name,
      place.address,
      place.city,
      'Bénin',
    ].whereType<String>().join(', ');
    final found = await _searchByName(query);
    if (found != null) {
      place.lat = found.$1;
      place.lng = found.$2;
      place.approximate = true;
    }
  }

  if (!place.hasPosition) {
    throw MapsImportException(
      'Aucune position trouvée. Dans Google Maps, ouvrez le lieu puis '
      '« Partager » → « Copier », ou copiez ses coordonnées.',
    );
  }
  if (!isInBenin(place.lat!, place.lng!)) {
    throw MapsImportException('Ce lieu se trouve hors du Bénin.');
  }

  await _reverseGeocode(place);
  place.department ??= departmentOfCity(place.city ?? '');
  return place;
}

const _fr = Locale('fr', 'BJ');
const _nominatim = 'nominatim.openstreetmap.org';
const _headers = {'User-Agent': 'TrackerBenin/1.0', 'Accept-Language': 'fr'};

String? _clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

/// Quartier, ville et département d'une position : géocodeur du téléphone
/// d'abord, OpenStreetMap (Nominatim) en secours.
Future<void> _reverseGeocode(MapsPlace place) async {
  try {
    final marks = await Geocoding(locale: _fr)
        .placemarkFromCoordinates(place.lat!, place.lng!);
    if (marks.isNotEmpty) {
      final m = marks.first;
      place.address ??= _clean(m.subLocality) ?? _clean(m.thoroughfare);
      place.city ??= _clean(m.locality) ?? _clean(m.subAdministrativeArea);
      place.department ??= matchDepartment(m.administrativeArea);
    }
  } catch (_) {
    // Géocodeur natif indisponible (web, appareil sans services Google).
  }
  if (place.address != null && place.city != null && place.department != null) {
    return;
  }
  try {
    final res = await http
        .get(
          Uri.https(_nominatim, '/reverse', {
            'format': 'jsonv2',
            'lat': '${place.lat}',
            'lon': '${place.lng}',
            'zoom': '18',
            'accept-language': 'fr',
          }),
          headers: kIsWeb ? null : _headers,
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return;
    final a = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['address'];
    if (a is! Map) return;
    String? pick(List<String> keys) =>
        keys.map((k) => _clean(a[k] as String?)).nonNulls.firstOrNull;
    place.address ??= pick([
      'neighbourhood',
      'suburb',
      'quarter',
      'hamlet',
      'city_district',
      'road',
    ]);
    place.city ??= pick(['city', 'town', 'municipality', 'village', 'county']);
    place.department ??=
        matchDepartment(a['state'] as String?) ??
        matchDepartment(a['county'] as String?);
  } catch (_) {
    // Sans réseau, l'administrateur complète les champs à la main.
  }
}

/// Recherche une position à partir d'un nom (résultat approximatif).
Future<(double, double)?> _searchByName(String query) async {
  try {
    final locs = await Geocoding(locale: _fr).locationFromAddress(query);
    if (locs.isNotEmpty) return (locs.first.latitude, locs.first.longitude);
  } catch (_) {}
  try {
    final res = await http
        .get(
          Uri.https(_nominatim, '/search', {
            'format': 'jsonv2',
            'q': query,
            'countrycodes': 'bj',
            'limit': '1',
          }),
          headers: kIsWeb ? null : _headers,
        )
        .timeout(const Duration(seconds: 15));
    final list = jsonDecode(utf8.decode(res.bodyBytes));
    if (list is List && list.isNotEmpty) {
      return (
        double.parse(list.first['lat'] as String),
        double.parse(list.first['lon'] as String),
      );
    }
  } catch (_) {}
  return null;
}
