import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../models.dart';
import 'repository.dart';

class FirebaseRepository implements Repository {
  FirebaseRepository() {
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _isAdmin = ValueNotifier<bool>(false);

  CollectionReference<Map<String, dynamic>> get _stations =>
      _db.collection('stations');
  CollectionReference<Map<String, dynamic>> get _pharmacies =>
      _db.collection('pharmacies');
  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  @override
  bool get isDemo => false;

  @override
  ValueListenable<bool> get isAdmin => _isAdmin;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null || user.isAnonymous) {
      _isAdmin.value = false;
      return;
    }
    _isAdmin.value = await _hasAdminRole(user.uid);
  }

  Future<bool> _hasAdminRole(String uid) async {
    try {
      return (await _db.collection('admins').doc(uid).get()).exists;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<List<Station>> watchStations() => _stations.snapshots().map(
    (s) => s.docs.map((d) => Station.fromMap(d.id, d.data())).toList(),
  );

  @override
  Stream<List<Pharmacy>> watchPharmacies({bool onDutyOnly = false}) {
    Query<Map<String, dynamic>> q = _pharmacies;
    if (onDutyOnly) {
      q = q.where('dutyEnd', isGreaterThan: Timestamp.now());
    }
    return q.snapshots().map(
      (s) => s.docs.map((d) => Pharmacy.fromMap(d.id, d.data())).toList(),
    );
  }

  @override
  Future<void> submitReport({
    required Station station,
    required bool hasFuel,
    required Uint8List photo,
    double? distanceMeters,
  }) async {
    // Connexion anonyme : chaque signalement est rattaché à un appareil.
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    final doc = _reports.doc();
    final ref = _storage.ref('reports/${user.uid}/${doc.id}.jpg');
    await ref.putData(photo, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await doc.set({
      'stationId': station.id,
      'stationName': station.name,
      'hasFuel': hasFuel,
      'userId': user.uid,
      'photoUrl': url,
      'distanceMeters': distanceMeters,
      'status': ReportStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> signInAdmin(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (!await _hasAdminRole(cred.user!.uid)) {
        await _auth.signOut();
        throw AdminAuthException(
          'Ce compte n\'a pas les droits administrateur.',
        );
      }
      _isAdmin.value = true;
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(switch (e.code) {
        'invalid-email' => 'Adresse e-mail invalide.',
        'user-disabled' => 'Ce compte a été désactivé.',
        'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
        'network-request-failed' => 'Pas de connexion Internet.',
        _ => 'E-mail ou mot de passe incorrect.',
      });
    }
  }

  @override
  Future<void> signOutAdmin() => _auth.signOut();

  @override
  Stream<List<FuelReport>> watchReports(ReportStatus status) => _reports
      .where('status', isEqualTo: status.name)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => FuelReport.fromMap(d.id, d.data())).toList(),
      );

  @override
  Future<void> reviewReport(FuelReport report, {required bool approve}) {
    final batch = _db.batch();
    batch.update(_reports.doc(report.id), {
      'status': (approve ? ReportStatus.approved : ReportStatus.rejected).name,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': _auth.currentUser?.uid,
    });
    if (approve) {
      batch.update(_stations.doc(report.stationId), {
        'status':
            (report.hasFuel ? FuelStatus.available : FuelStatus.unavailable)
                .name,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  @override
  Future<void> saveStation(Station station) => station.id.isEmpty
      ? _stations.add(station.toMap())
      : _stations.doc(station.id).set(station.toMap());

  @override
  Future<void> deleteStation(String id) => _stations.doc(id).delete();

  @override
  Future<void> savePharmacy(Pharmacy pharmacy) => pharmacy.id.isEmpty
      ? _pharmacies.add(pharmacy.toMap())
      : _pharmacies.doc(pharmacy.id).set(pharmacy.toMap());

  @override
  Future<void> deletePharmacy(String id) => _pharmacies.doc(id).delete();

  @override
  Future<void> setDutyList(DateTimeRange period, Set<String> ids) async {
    final all = await _pharmacies.get();
    final start = Timestamp.fromDate(period.start);
    final end = Timestamp.fromDate(period.end);
    var batch = _db.batch();
    var count = 0;
    for (final doc in all.docs) {
      final p = Pharmacy.fromMap(doc.id, doc.data());
      if (ids.contains(doc.id)) {
        batch.update(doc.reference, {'dutyStart': start, 'dutyEnd': end});
      } else if (p.dutyStart != null &&
          p.dutyEnd != null &&
          p.dutyStart!.isBefore(period.end) &&
          p.dutyEnd!.isAfter(period.start)) {
        // Retirée de la liste pour cette période.
        batch.update(doc.reference, {'dutyStart': null, 'dutyEnd': null});
      } else {
        continue;
      }
      if (++count == 400) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }
}
