import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;
Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);
double _num(dynamic v) => v is num ? v.toDouble() : 0;

/// État du carburant dans une station, tel que certifié par l'administrateur.
enum FuelStatus {
  available,
  unavailable,
  unknown;

  static FuelStatus parse(String? v) => FuelStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => FuelStatus.unknown,
  );
}

class Station {
  const Station({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
    this.department = '',
    this.status = FuelStatus.unknown,
    this.statusUpdatedAt,
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final String department;
  final FuelStatus status;

  /// Somme et nombre des notes des usagers (agrégat mis à jour à chaque avis).
  final int ratingSum;
  final int ratingCount;
  double? get rating => ratingCount == 0 ? null : ratingSum / ratingCount;

  /// Date de la dernière certification par un administrateur.
  final DateTime? statusUpdatedAt;

  factory Station.fromMap(String id, Map<String, dynamic> m) => Station(
    id: id,
    name: m['name'] as String? ?? '',
    address: m['address'] as String? ?? '',
    city: m['city'] as String? ?? '',
    lat: _num(m['lat']),
    lng: _num(m['lng']),
    department: m['department'] as String? ?? '',
    status: FuelStatus.parse(m['status'] as String?),
    statusUpdatedAt: _date(m['statusUpdatedAt']),
    ratingSum: (m['ratingSum'] as num?)?.toInt() ?? 0,
    ratingCount: (m['ratingCount'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'city': city,
    'lat': lat,
    'lng': lng,
    'department': department,
    'status': status.name,
    'statusUpdatedAt': _ts(statusUpdatedAt),
  };

  Station copyWith({
    String? id,
    FuelStatus? status,
    DateTime? statusUpdatedAt,
    int? ratingSum,
    int? ratingCount,
  }) => Station(
    id: id ?? this.id,
    name: name,
    address: address,
    city: city,
    lat: lat,
    lng: lng,
    department: department,
    status: status ?? this.status,
    statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
    ratingSum: ratingSum ?? this.ratingSum,
    ratingCount: ratingCount ?? this.ratingCount,
  );
}

class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.lat,
    required this.lng,
    this.department = '',
    this.dutyStart,
    this.dutyEnd,
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final double lat;
  final double lng;
  final String department;
  final int ratingSum;
  final int ratingCount;
  double? get rating => ratingCount == 0 ? null : ratingSum / ratingCount;

  /// Période de garde en cours ou à venir (liste officielle hebdomadaire).
  final DateTime? dutyStart;
  final DateTime? dutyEnd;

  bool isOnDutyAt(DateTime t) =>
      dutyStart != null &&
      dutyEnd != null &&
      !t.isBefore(dutyStart!) &&
      t.isBefore(dutyEnd!);

  factory Pharmacy.fromMap(String id, Map<String, dynamic> m) => Pharmacy(
    id: id,
    name: m['name'] as String? ?? '',
    address: m['address'] as String? ?? '',
    city: m['city'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    lat: _num(m['lat']),
    lng: _num(m['lng']),
    department: m['department'] as String? ?? '',
    dutyStart: _date(m['dutyStart']),
    dutyEnd: _date(m['dutyEnd']),
    ratingSum: (m['ratingSum'] as num?)?.toInt() ?? 0,
    ratingCount: (m['ratingCount'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'city': city,
    'phone': phone,
    'lat': lat,
    'lng': lng,
    'department': department,
    'dutyStart': _ts(dutyStart),
    'dutyEnd': _ts(dutyEnd),
  };

  Pharmacy withDuty(DateTime? start, DateTime? end) =>
      _copy(dutyStart: start, dutyEnd: end, keepDuty: false);

  Pharmacy copyWith({String? id, int? ratingSum, int? ratingCount}) =>
      _copy(id: id, ratingSum: ratingSum, ratingCount: ratingCount);

  Pharmacy _copy({
    String? id,
    DateTime? dutyStart,
    DateTime? dutyEnd,
    bool keepDuty = true,
    int? ratingSum,
    int? ratingCount,
  }) => Pharmacy(
    id: id ?? this.id,
    name: name,
    address: address,
    city: city,
    phone: phone,
    lat: lat,
    lng: lng,
    department: department,
    dutyStart: keepDuty ? this.dutyStart : dutyStart,
    dutyEnd: keepDuty ? this.dutyEnd : dutyEnd,
    ratingSum: ratingSum ?? this.ratingSum,
    ratingCount: ratingCount ?? this.ratingCount,
  );
}

enum ReportStatus {
  pending,
  approved,
  rejected;

  static ReportStatus parse(String? v) => ReportStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => ReportStatus.pending,
  );
}

/// Signalement d'un utilisateur, avec photo prise en direct.
class FuelReport {
  const FuelReport({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.hasFuel,
    required this.userId,
    required this.createdAt,
    this.photoUrl,
    this.photoBytes,
    this.distanceMeters,
    this.status = ReportStatus.pending,
    this.reviewedAt,
  });

  final String id;
  final String stationId;
  final String stationName;
  final bool hasFuel;
  final String userId;
  final DateTime createdAt;
  final String? photoUrl;

  /// Photo conservée en mémoire (mode démo uniquement).
  final Uint8List? photoBytes;

  /// Distance entre l'utilisateur et la station au moment du signalement.
  final double? distanceMeters;
  final ReportStatus status;
  final DateTime? reviewedAt;

  factory FuelReport.fromMap(String id, Map<String, dynamic> m) => FuelReport(
    id: id,
    stationId: m['stationId'] as String? ?? '',
    stationName: m['stationName'] as String? ?? '',
    hasFuel: m['hasFuel'] as bool? ?? false,
    userId: m['userId'] as String? ?? '',
    createdAt: _date(m['createdAt']) ?? DateTime.now(),
    photoUrl: m['photoUrl'] as String?,
    distanceMeters: (m['distanceMeters'] as num?)?.toDouble(),
    status: ReportStatus.parse(m['status'] as String?),
    reviewedAt: _date(m['reviewedAt']),
  );

  FuelReport reviewed(ReportStatus s) => FuelReport(
    id: id,
    stationId: stationId,
    stationName: stationName,
    hasFuel: hasFuel,
    userId: userId,
    createdAt: createdAt,
    photoUrl: photoUrl,
    photoBytes: photoBytes,
    distanceMeters: distanceMeters,
    status: s,
    reviewedAt: DateTime.now(),
  );
}

/// Avis d'un usager sur une station ou une pharmacie (un seul par usager
/// et par lieu, modifiable).
class Review {
  const Review({
    required this.id,
    required this.placeId,
    required this.isPharmacy,
    required this.userId,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.updatedAt,
  });

  final String id;
  final String placeId;
  final bool isPharmacy;
  final String userId;
  final String authorName;

  /// Note de 1 à 5.
  final int rating;
  final String comment;
  final DateTime updatedAt;

  factory Review.fromMap(String id, Map<String, dynamic> m) => Review(
    id: id,
    placeId: m['placeId'] as String? ?? '',
    isPharmacy: m['placeType'] == 'pharmacy',
    userId: m['userId'] as String? ?? '',
    authorName: m['authorName'] as String? ?? '',
    rating: (m['rating'] as num?)?.toInt() ?? 0,
    comment: m['comment'] as String? ?? '',
    updatedAt: _date(m['updatedAt']) ?? DateTime.now(),
  );
}
