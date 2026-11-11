import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// Signalement de la disponibilité d'essence, avec photo prise en direct.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.station});

  /// Station présélectionnée ; sinon l'utilisateur la choisit.
  final Station? station;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Station? _station = widget.station;
  bool? _hasFuel;
  Uint8List? _photo;
  bool _sending = false;

  bool get _ready => _station != null && _hasFuel != null && _photo != null;

  Future<void> _pickStation() async {
    final picked = await showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _StationPicker(),
    );
    if (picked != null) setState(() => _station = picked);
  }

  /// Ouvre directement l'appareil photo : la galerie n'est jamais proposée.
  Future<void> _takePhoto() async {
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        imageQuality: 60,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Appareil photo indisponible. Autorisez l\'accès à la caméra.',
          error: true,
        );
      }
    }
  }

  Future<void> _submit() async {
    final station = _station!;
    setState(() => _sending = true);
    try {
      await repo.submitReport(
        station: station,
        hasFuel: _hasFuel!,
        photo: _photo!,
        distanceMeters: location.hasFix
            ? location.distanceTo(station.lat, station.lng)
            : null,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.green,
            size: 52,
          ),
          title: const Text('Merci pour votre aide !'),
          content: const Text(
            'Votre signalement a bien été envoyé. Il sera publié après '
            'vérification par un administrateur.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Terminer'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showMessage(
        context,
        'Envoi impossible. Vérifiez votre connexion puis réessayez.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler une station')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const _StepTitle(1, 'Quelle station ?'),
          _station == null
              ? OutlinedButton.icon(
                  onPressed: _pickStation,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(60),
                  ),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Choisir une station proche'),
                )
              : Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                    leading: const IconBadge(
                      icon: Icons.local_gas_station_rounded,
                      bg: AppColors.neutralBg,
                      fg: AppColors.ink,
                    ),
                    title: Text(
                      _station!.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${_station!.address} · ${_station!.city}'),
                    trailing: TextButton(
                      onPressed: _sending ? null : _pickStation,
                      child: const Text('Changer'),
                    ),
                  ),
                ),
          const _StepTitle(2, 'Que constatez-vous ?'),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  label: 'Il y a de l\'essence',
                  icon: Icons.check_circle_rounded,
                  bg: AppColors.okBg,
                  fg: AppColors.okFg,
                  selected: _hasFuel == true,
                  onTap: () => setState(() => _hasFuel = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceTile(
                  label: 'Pas d\'essence',
                  icon: Icons.cancel_rounded,
                  bg: AppColors.koBg,
                  fg: AppColors.koFg,
                  selected: _hasFuel == false,
                  onTap: () => setState(() => _hasFuel = false),
                ),
              ),
            ],
          ),
          const _StepTitle(3, 'Photo de la station'),
          _PhotoZone(photo: _photo, onTap: _sending ? null : _takePhoto),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppColors.muted,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La photo doit être prise sur place, maintenant. '
                  'Les images de la galerie ne sont pas acceptées.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _ready && !_sending ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Envoyer le signalement'),
          ),
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.number, this.title);
  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.ink,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? bg : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? fg : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 34, color: selected ? fg : AppColors.muted),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? fg : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoZone extends StatelessWidget {
  const _PhotoZone({required this.photo, required this.onTap});
  final Uint8List? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.ink,
                child: Icon(Icons.photo_camera_rounded, color: Colors.white),
              ),
              SizedBox(height: 12),
              Text(
                'Prendre une photo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              SizedBox(height: 2),
              Text(
                'Les pompes ou l\'enseigne bien visibles',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Image.memory(
            photo!,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: FilledButton.tonalIcon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
                minimumSize: const Size(0, 40),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reprendre'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille de sélection : stations triées par distance, avec recherche.
class _StationPicker extends StatefulWidget {
  const _StationPicker();

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  final _stream = repo.watchStations();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
              decoration: const InputDecoration(
                hintText: 'Rechercher une station ou un quartier',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Station>>(
              stream: _stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items =
                    snap.data!
                        .where(
                          (s) => '${s.name} ${s.address} ${s.city}'
                              .toLowerCase()
                              .contains(_query),
                        )
                        .map((s) => (s, location.distanceTo(s.lat, s.lng)))
                        .toList()
                      ..sort((a, b) => a.$2.compareTo(b.$2));
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucune station trouvée',
                    text: 'Essayez un autre nom ou un autre quartier.',
                  );
                }
                return ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final (s, d) = items[i];
                    return Card(
                      child: ListTile(
                        onTap: () => Navigator.pop(context, s),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${s.address} · ${s.city}'),
                        trailing: Text(
                          formatDistance(d),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
