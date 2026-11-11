import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../models.dart';
import 'location_service.dart';

/// Accès aux données. Deux implémentations : Firebase (production) et
/// démo (données locales, utilisée tant que Firebase n'est pas configuré).
abstract class Repository {
  bool get isDemo;

  /// Vrai lorsqu'un administrateur est connecté.
  ValueListenable<bool> get isAdmin;

  Stream<List<Station>> watchStations();

  /// [onDutyOnly] limite la lecture aux pharmacies dont la garde n'est pas
  /// terminée (écran public) ; sinon tout l'annuaire (back office).
  Stream<List<Pharmacy>> watchPharmacies({bool onDutyOnly = false});

  /// Envoie un signalement avec sa photo ; il reste « en attente » jusqu'à
  /// la certification par un administrateur.
  Future<void> submitReport({
    required Station station,
    required bool hasFuel,
    required Uint8List photo,
    double? distanceMeters,
  });

  // ----- Back office -----
  Future<void> signInAdmin(String email, String password);
  Future<void> signOutAdmin();

  Stream<List<FuelReport>> watchReports(ReportStatus status);
  Future<void> reviewReport(FuelReport report, {required bool approve});

  Future<void> saveStation(Station station);
  Future<void> deleteStation(String id);

  Future<void> savePharmacy(Pharmacy pharmacy);
  Future<void> deletePharmacy(String id);

  /// Enregistre la liste officielle de garde pour la période donnée.
  Future<void> setDutyList(DateTimeRange period, Set<String> pharmacyIds);
}

class AdminAuthException implements Exception {
  AdminAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Services globaux de l'application.
late Repository repo;
final location = LocationService();
