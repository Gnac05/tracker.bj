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
    this.status = FuelStatus.unknown,
    this.statusUpdatedAt,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final FuelStatus status;

  /// Date de la dernière certification par un administrateur.
  final DateTime? statusUpdatedAt;

  factory Station.fromMap(String id, Map<String, dynamic> m) => Station(
    id: id,
    name: m['name'] as String? ?? '',
    address: m['address'] as String? ?? '',
    city: m['city'] as String? ?? '',
    lat: _num(m['lat']),
    lng: _num(m['lng']),
    status: FuelStatus.parse(m['status'] as String?),
    statusUpdatedAt: _date(m['statusUpdatedAt']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'city': city,
    'lat': lat,
    'lng': lng,
    'status': status.name,
    'statusUpdatedAt': _ts(statusUpdatedAt),
  };

  Station copyWith({FuelStatus? status, DateTime? statusUpdatedAt}) => Station(
    id: id,
    name: name,
    address: address,
    city: city,
    lat: lat,
    lng: lng,
    status: status ?? this.status,
    statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
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
    this.dutyStart,
    this.dutyEnd,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final double lat;
  final double lng;

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
    dutyStart: _date(m['dutyStart']),
    dutyEnd: _date(m['dutyEnd']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'city': city,
    'phone': phone,
    'lat': lat,
    'lng': lng,
    'dutyStart': _ts(dutyStart),
    'dutyEnd': _ts(dutyEnd),
  };

  Pharmacy withDuty(DateTime? start, DateTime? end) => Pharmacy(
    id: id,
    name: name,
    address: address,
    city: city,
    phone: phone,
    lat: lat,
    lng: lng,
    dutyStart: start,
    dutyEnd: end,
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
