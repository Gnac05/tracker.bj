import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/models.dart';
import 'package:tracker/services/maps_import.dart';
import 'package:tracker/utils.dart';

void main() {
  group('Lecture d\'un lien Google Maps', () {
    test('lien complet : nom, adresse, ville et coordonnées exactes', () {
      final p = parseMapsText(
        'https://www.google.com/maps/place/Pharmacie+Camp+Gu%C3%A9zo,+Rue+240,+Cotonou/'
        '@6.3601,2.4105,17z/data=!3m1!4b1!4m6!3m5!1s0x1:0x2!8m2!3d6.3521234!4d2.4189876',
      );
      expect(p.name, 'Pharmacie Camp Guézo');
      expect(p.address, 'Rue 240');
      expect(p.city, 'Cotonou');
      // Les coordonnées du lieu priment sur le centre de la carte (@…).
      expect(p.lat, 6.3521234);
      expect(p.lng, 2.4189876);
      expect(p.approximate, isFalse);
    });

    test('centre de carte seul : position marquée approximative', () {
      final p = parseMapsText(
        'https://www.google.com/maps/place/Station+X/@6.3601,2.4105,17z',
      );
      expect(p.lat, 6.3601);
      expect(p.approximate, isTrue);
    });

    test('texte de partage : le nom précède le lien court', () {
      final p = parseMapsText(
        'Pharmacie Les Cocotiers\nhttps://maps.app.goo.gl/AbCdEf123',
      );
      expect(p.name, 'Pharmacie Les Cocotiers');
      expect(p.hasPosition, isFalse);
    });

    test('épingle déposée : coordonnées en paramètre', () {
      final p = parseMapsText('https://maps.google.com/?q=6.4969,2.6289');
      expect(p.lat, 6.4969);
      expect(p.lng, 2.6289);
      expect(p.name, isNull);
    });

    test('coordonnées brutes copiées depuis Google Maps', () {
      final p = parseMapsText('9.337241, 2.630312');
      expect(p.lat, 9.337241);
      expect(p.lng, 2.630312);
    });

    test('texte sans rien d\'exploitable', () {
      expect(parseMapsText('bonjour').hasPosition, isFalse);
    });
  });

  test('départements du Bénin', () {
    expect(departmentOfCity('Cotonou'), 'Littoral');
    expect(departmentOfCity('porto-novo'), 'Ouémé');
    expect(departmentOfCity('Ville inconnue'), isNull);
    expect(matchDepartment('Littoral Department'), 'Littoral');
    expect(matchDepartment('Département de l\'Ouémé'), 'Ouémé');
    expect(matchDepartment('Lagos'), isNull);
    expect(matchCity('ABOMEY CALAVI'), 'Abomey-Calavi');
  });

  test('note moyenne d\'un lieu', () {
    const s = Station(
      id: 's',
      name: 'S',
      address: '',
      city: 'Cotonou',
      lat: 6.36,
      lng: 2.41,
      ratingSum: 13,
      ratingCount: 3,
    );
    expect(formatRating(s.rating!), '4,3');
    expect(s.copyWith(ratingSum: 0, ratingCount: 0).rating, isNull);
  });
}
