import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../models.dart';
import '../utils.dart';
import 'repository.dart';

/// Liste en mémoire observable.
class _Store<T> {
  _Store(this.items);
  List<T> items;
  final _ctrl = StreamController<List<T>>.broadcast();

  Stream<List<T>> watch() async* {
    yield List.of(items);
    yield* _ctrl.stream;
  }

  void update(List<T> next) {
    items = next;
    _ctrl.add(List.of(items));
  }
}

/// Données fictives, en mémoire, pour découvrir l'application avant la
/// configuration de Firebase. Rien n'est conservé à la fermeture.
class DemoRepository implements Repository {
  DemoRepository() {
    final now = DateTime.now();
    final week = currentWeek();
    Station st(
      String id,
      String zone,
      String city,
      double lat,
      double lng,
      FuelStatus s,
      int minutesAgo,
    ) => Station(
      id: id,
      name: 'Station démo $zone',
      address: 'Quartier $zone',
      city: city,
      lat: lat,
      lng: lng,
      department: departmentOfCity(city) ?? '',
      status: s,
      statusUpdatedAt: s == FuelStatus.unknown
          ? null
          : now.subtract(Duration(minutes: minutesAgo)),
    );
    Pharmacy ph(
      String id,
      String zone,
      String city,
      double lat,
      double lng,
      bool duty,
    ) => Pharmacy(
      id: id,
      name: 'Pharmacie démo $zone',
      address: 'Quartier $zone',
      city: city,
      phone: '01 00 00 00 0${id.substring(1)}',
      lat: lat,
      lng: lng,
      department: departmentOfCity(city) ?? '',
      dutyStart: duty ? week.start : null,
      dutyEnd: duty ? week.end : null,
    );

    _stations = _Store([
      st(
        's1',
        'Cadjèhoun',
        'Cotonou',
        6.3573,
        2.3920,
        FuelStatus.available,
        25,
      ),
      st('s2', 'Akpakpa', 'Cotonou', 6.3660, 2.4480, FuelStatus.available, 140),
      st(
        's3',
        'Gbégamey',
        'Cotonou',
        6.3640,
        2.4080,
        FuelStatus.unavailable,
        60,
      ),
      st(
        's4',
        'Fidjrossè',
        'Cotonou',
        6.3560,
        2.3660,
        FuelStatus.available,
        310,
      ),
      st(
        's5',
        'Godomey',
        'Abomey-Calavi',
        6.3850,
        2.3420,
        FuelStatus.unknown,
        0,
      ),
      st(
        's6',
        'Zogbadjè',
        'Abomey-Calavi',
        6.4200,
        2.3400,
        FuelStatus.available,
        45,
      ),
      st(
        's7',
        'Ouando',
        'Porto-Novo',
        6.5010,
        2.6190,
        FuelStatus.available,
        500,
      ),
      st(
        's8',
        'Sainte-Rita',
        'Cotonou',
        6.3780,
        2.4150,
        FuelStatus.unavailable,
        20,
      ),
    ]);
    _pharmacies = _Store([
      ph('p1', 'Saint-Michel', 'Cotonou', 6.3650, 2.4250, true),
      ph('p2', 'Haie Vive', 'Cotonou', 6.3560, 2.3990, true),
      ph('p3', 'Akpakpa', 'Cotonou', 6.3640, 2.4560, false),
      ph('p4', 'Calavi Kpota', 'Abomey-Calavi', 6.4410, 2.3480, true),
      ph('p5', 'Agla', 'Cotonou', 6.3720, 2.3800, true),
      ph('p6', 'Catchi', 'Porto-Novo', 6.4840, 2.6230, true),
      ph('p7', 'Vèdoko', 'Cotonou', 6.3760, 2.3990, false),
    ]);
    _reports = _Store([
      FuelReport(
        id: 'r1',
        stationId: 's5',
        stationName: 'Station démo Godomey',
        hasFuel: true,
        userId: 'demo',
        createdAt: now.subtract(const Duration(minutes: 8)),
        distanceMeters: 35,
      ),
      FuelReport(
        id: 'r2',
        stationId: 's2',
        stationName: 'Station démo Akpakpa',
        hasFuel: false,
        userId: 'demo',
        createdAt: now.subtract(const Duration(minutes: 31)),
        distanceMeters: 1240,
      ),
    ]);
    Review rv(
      String place,
      String user,
      String author,
      int rating,
      String comment,
      int hoursAgo,
    ) => Review(
      id: '${place}_$user',
      placeId: place,
      isPharmacy: place.startsWith('p'),
      userId: user,
      authorName: author,
      rating: rating,
      comment: comment,
      updatedAt: now.subtract(Duration(hours: hoursAgo)),
    );
    _reviews = _Store([
      rv(
        's1',
        'u1',
        'Koffi',
        5,
        'Servi en cinq minutes, pompistes aimables.',
        3,
      ),
      rv('s1', 'u2', 'Aïcha', 4, 'Un peu de file le matin mais ça avance.', 26),
      rv('s1', 'u3', '', 3, '', 80),
      rv('s2', 'u1', 'Koffi', 2, 'Souvent en rupture le week-end.', 50),
      rv('p1', 'u2', 'Aïcha', 5, 'Ouverte toute la nuit, bon accueil.', 5),
      rv('p1', 'u4', 'Rodrigue', 4, 'Bien approvisionnée.', 40),
    ]);
    for (final id in {for (final r in _reviews.items) r.placeId}) {
      _recount(id, id.startsWith('p'));
    }
  }

  late final _Store<Review> _reviews;
  late final _Store<Station> _stations;
  late final _Store<Pharmacy> _pharmacies;
  late final _Store<FuelReport> _reports;
  final _isAdmin = ValueNotifier<bool>(false);
  int _seq = 100;

  Future<void> _lag() => Future.delayed(const Duration(milliseconds: 350));

  @override
  bool get isDemo => true;

  @override
  ValueListenable<bool> get isAdmin => _isAdmin;

  @override
  Stream<List<Station>> watchStations() => _stations.watch();

  @override
  Stream<List<Pharmacy>> watchPharmacies({bool onDutyOnly = false}) =>
      _pharmacies.watch();

  @override
  Future<void> submitReport({
    required Station station,
    required bool hasFuel,
    required Uint8List photo,
    double? distanceMeters,
  }) async {
    await _lag();
    _reports.update([
      FuelReport(
        id: 'r${_seq++}',
        stationId: station.id,
        stationName: station.name,
        hasFuel: hasFuel,
        userId: 'demo',
        createdAt: DateTime.now(),
        photoBytes: photo,
        distanceMeters: distanceMeters,
      ),
      ..._reports.items,
    ]);
  }

  @override
  Future<void> signInAdmin(String email, String password) async {
    await _lag();
    if (email.trim().isEmpty || password.isEmpty) {
      throw AdminAuthException('Saisissez un e-mail et un mot de passe.');
    }
    _isAdmin.value = true;
  }

  @override
  Future<void> signOutAdmin() async => _isAdmin.value = false;

  @override
  Stream<List<FuelReport>> watchReports(ReportStatus status) =>
      _reports.watch().map((l) => l.where((r) => r.status == status).toList());

  @override
  Future<void> reviewReport(FuelReport report, {required bool approve}) async {
    await _lag();
    _reports.update([
      for (final r in _reports.items)
        r.id == report.id
            ? r.reviewed(
                approve ? ReportStatus.approved : ReportStatus.rejected,
              )
            : r,
    ]);
    if (!approve) return;
    _stations.update([
      for (final s in _stations.items)
        s.id == report.stationId
            ? s.copyWith(
                status: report.hasFuel
                    ? FuelStatus.available
                    : FuelStatus.unavailable,
                statusUpdatedAt: DateTime.now(),
              )
            : s,
    ]);
  }

  @override
  Future<void> saveStation(Station station) async {
    await _lag();
    if (station.id.isEmpty) {
      _stations.update([
        ..._stations.items,
        station.copyWith(id: 's${_seq++}'),
      ]);
    } else {
      _stations.update([
        for (final s in _stations.items) s.id == station.id ? station : s,
      ]);
    }
  }

  @override
  Future<void> deleteStation(String id) async {
    _stations.update(_stations.items.where((s) => s.id != id).toList());
  }

  @override
  Future<void> savePharmacy(Pharmacy pharmacy) async {
    await _lag();
    if (pharmacy.id.isEmpty) {
      _pharmacies.update([
        ..._pharmacies.items,
        pharmacy.copyWith(id: 'p${_seq++}'),
      ]);
    } else {
      _pharmacies.update([
        for (final p in _pharmacies.items) p.id == pharmacy.id ? pharmacy : p,
      ]);
    }
  }

  @override
  Future<void> deletePharmacy(String id) async {
    _pharmacies.update(_pharmacies.items.where((p) => p.id != id).toList());
  }

  @override
  Future<void> setDutyList(DateTimeRange period, Set<String> ids) async {
    await _lag();
    _pharmacies.update([
      for (final p in _pharmacies.items)
        if (ids.contains(p.id))
          p.withDuty(period.start, period.end)
        else if (p.dutyStart != null &&
            p.dutyStart!.isBefore(period.end) &&
            p.dutyEnd!.isAfter(period.start))
          p.withDuty(null, null)
        else
          p,
    ]);
  }

  @override
  String? get currentUserId => 'demo';

  @override
  Stream<List<Review>> watchReviews(String placeId) => _reviews.watch().map(
    (l) =>
        l.where((r) => r.placeId == placeId).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Future<void> submitReview({
    required String placeId,
    required bool isPharmacy,
    required int rating,
    required String comment,
    required String authorName,
  }) async {
    await _lag();
    final id = '${placeId}_demo';
    _reviews.update([
      Review(
        id: id,
        placeId: placeId,
        isPharmacy: isPharmacy,
        userId: 'demo',
        authorName: authorName,
        rating: rating,
        comment: comment,
        updatedAt: DateTime.now(),
      ),
      ..._reviews.items.where((r) => r.id != id),
    ]);
    _recount(placeId, isPharmacy);
  }

  @override
  Future<void> deleteReview(Review review) async {
    _reviews.update(_reviews.items.where((r) => r.id != review.id).toList());
    _recount(review.placeId, review.isPharmacy);
  }

  /// Recalcule la note agrégée d'un lieu à partir de ses avis.
  void _recount(String placeId, bool isPharmacy) {
    final rs = _reviews.items.where((r) => r.placeId == placeId);
    final sum = rs.fold(0, (a, r) => a + r.rating);
    if (isPharmacy) {
      _pharmacies.update([
        for (final p in _pharmacies.items)
          p.id == placeId
              ? p.copyWith(ratingSum: sum, ratingCount: rs.length)
              : p,
      ]);
    } else {
      _stations.update([
        for (final s in _stations.items)
          s.id == placeId
              ? s.copyWith(ratingSum: sum, ratingCount: rs.length)
              : s,
      ]);
    }
  }
}
