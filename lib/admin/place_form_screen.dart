import 'package:flutter/material.dart';

import '../models.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../utils.dart';

/// Formulaire d'ajout / modification d'une station ou d'une pharmacie.
/// Passez [station] ou [pharmacy] pour modifier, ou seulement [isPharmacy]
/// pour créer.
class PlaceFormScreen extends StatefulWidget {
  const PlaceFormScreen({
    super.key,
    required this.isPharmacy,
    this.station,
    this.pharmacy,
  });

  final bool isPharmacy;
  final Station? station;
  final Pharmacy? pharmacy;

  @override
  State<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends State<PlaceFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.station?.name ?? widget.pharmacy?.name,
  );
  late final _address = TextEditingController(
    text: widget.station?.address ?? widget.pharmacy?.address,
  );
  late final _phone = TextEditingController(text: widget.pharmacy?.phone);
  late final _lat = TextEditingController(
    text: (widget.station?.lat ?? widget.pharmacy?.lat)?.toString(),
  );
  late final _lng = TextEditingController(
    text: (widget.station?.lng ?? widget.pharmacy?.lng)?.toString(),
  );
  late String _city = () {
    final c = widget.station?.city ?? widget.pharmacy?.city;
    return c != null && beninCities.contains(c) ? c : beninCities.first;
  }();
  late FuelStatus _status = widget.station?.status ?? FuelStatus.unknown;
  bool _busy = false;

  bool get _editing => widget.station != null || widget.pharmacy != null;
  String get _id => widget.station?.id ?? widget.pharmacy?.id ?? '';
  String get _kind => widget.isPharmacy ? 'pharmacie' : 'station';

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  Future<void> _useMyPosition() async {
    await location.refresh();
    if (!mounted) return;
    if (!location.hasFix) {
      showMessage(context, 'Position GPS indisponible.', error: true);
      return;
    }
    setState(() {
      _lat.text = location.lat.toStringAsFixed(6);
      _lng.text = location.lng.toStringAsFixed(6);
    });
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, done);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Enregistrement impossible.', error: true);
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final lat = _parse(_lat.text)!;
    final lng = _parse(_lng.text)!;
    if (widget.isPharmacy) {
      final old = widget.pharmacy;
      _run(
        () => repo.savePharmacy(
          Pharmacy(
            id: _id,
            name: _name.text.trim(),
            address: _address.text.trim(),
            city: _city,
            phone: _phone.text.trim(),
            lat: lat,
            lng: lng,
            dutyStart: old?.dutyStart,
            dutyEnd: old?.dutyEnd,
          ),
        ),
        'Pharmacie enregistrée.',
      );
    } else {
      final old = widget.station;
      _run(
        () => repo.saveStation(
          Station(
            id: _id,
            name: _name.text.trim(),
            address: _address.text.trim(),
            city: _city,
            lat: lat,
            lng: lng,
            status: _status,
            statusUpdatedAt: _status == old?.status
                ? old?.statusUpdatedAt
                : (_status == FuelStatus.unknown ? null : DateTime.now()),
          ),
        ),
        'Station enregistrée.',
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer cette $_kind ?'),
        content: Text('« ${_name.text} » sera retirée de l\'application.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.koFg),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _run(
      () => widget.isPharmacy
          ? repo.deletePharmacy(_id)
          : repo.deleteStation(_id),
      'Suppression effectuée.',
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifier la $_kind' : 'Nouvelle $_kind'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextFormField(
              controller: _name,
              validator: _required,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: widget.isPharmacy
                    ? 'Nom de la pharmacie'
                    : 'Nom de la station',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              validator: _required,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Quartier / repère',
                hintText: 'Ex. : Cadjèhoun, face à la mairie',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'Ville'),
              items: [
                for (final c in beninCities)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _city = v!),
            ),
            if (widget.isPharmacy) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  hintText: '01 XX XX XX XX',
                  prefixText: '+229  ',
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'Position GPS',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Sur place, utilisez votre position. Sinon, copiez les '
              'coordonnées depuis Google Maps (appui long sur le lieu).',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _coord(_lat, 'Latitude', '6.3654')),
                const SizedBox(width: 12),
                Expanded(child: _coord(_lng, 'Longitude', '2.4183')),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _useMyPosition,
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              icon: const Icon(Icons.my_location_rounded, size: 20),
              label: const Text('Utiliser ma position actuelle'),
            ),
            if (!widget.isPharmacy) ...[
              const SizedBox(height: 22),
              Text(
                'État certifié',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SegmentedButton<FuelStatus>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: FuelStatus.available,
                    label: Text('Essence'),
                  ),
                  ButtonSegment(
                    value: FuelStatus.unavailable,
                    label: Text('Rupture'),
                  ),
                  ButtonSegment(
                    value: FuelStatus.unknown,
                    label: Text('Inconnu'),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: (s) => setState(() => _status = s.first),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: Text(_busy ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ),
      ),
    );
  }

  Widget _coord(TextEditingController c, String label, String hint) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (_) {
        final lat = _parse(_lat.text);
        final lng = _parse(_lng.text);
        if (_parse(c.text) == null) return 'Nombre invalide';
        if (lat != null && lng != null && !isInBenin(lat, lng)) {
          return 'Hors du Bénin';
        }
        return null;
      },
    );
  }
}
