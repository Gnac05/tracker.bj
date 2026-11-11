import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/models.dart';
import 'package:tracker/utils.dart';

void main() {
  test('formatDistance affiche mètres puis kilomètres', () {
    expect(formatDistance(42), '40 m');
    expect(formatDistance(1240), '1,2 km');
    expect(formatDistance(23600), '24 km');
  });

  test('isInBenin valide les coordonnées', () {
    expect(isInBenin(6.3654, 2.4183), isTrue); // Cotonou
    expect(isInBenin(9.3372, 2.6303), isTrue); // Parakou
    expect(isInBenin(48.8566, 2.3522), isFalse); // Paris
  });

  test('une pharmacie est de garde uniquement pendant sa période', () {
    final week = currentWeek();
    final p = Pharmacy(
      id: 'p',
      name: 'Test',
      address: '',
      city: 'Cotonou',
      phone: '',
      lat: 6.36,
      lng: 2.41,
      dutyStart: week.start,
      dutyEnd: week.end,
    );
    expect(p.isOnDutyAt(DateTime.now()), isTrue);
    expect(p.isOnDutyAt(week.end), isFalse);
    expect(p.withDuty(null, null).isOnDutyAt(DateTime.now()), isFalse);
  });
}
