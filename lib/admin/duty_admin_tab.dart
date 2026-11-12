import 'package:flutter/material.dart';

import '../models.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// Saisie hebdomadaire de la liste officielle des pharmacies de garde :
/// l'administrateur choisit la période puis coche les pharmacies concernées.
class DutyAdminTab extends StatefulWidget {
  const DutyAdminTab({super.key});

  @override
  State<DutyAdminTab> createState() => _DutyAdminTabState();
}

class _DutyAdminTabState extends State<DutyAdminTab> {
  final _stream = repo.watchPharmacies();

  /// Fin exclusive (lendemain 00h00 du dernier jour de garde).
  DateTimeRange _period = currentWeek();
  Set<String>? _selected;
  String _query = '';
  bool _busy = false;

  bool _overlaps(Pharmacy p) =>
      p.dutyStart != null &&
      p.dutyEnd != null &&
      p.dutyStart!.isBefore(_period.end) &&
      p.dutyEnd!.isAfter(_period.start);

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: DateTimeRange(
        start: _period.start,
        end: _period.end.subtract(const Duration(days: 1)),
      ),
      helpText: 'Période de garde',
      saveText: 'Valider',
      // Sur grand écran, le calendrier s'ouvre en fenêtre et non en plein écran.
      builder: (context, child) => MediaQuery.sizeOf(context).width < 720
          ? child!
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                  maxHeight: 680,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: child,
                ),
              ),
            ),
    );
    if (picked == null) return;
    setState(() {
      _period = DateTimeRange(
        start: picked.start,
        end: picked.end.add(const Duration(days: 1)),
      );
      _selected = null; // recalculée d'après la nouvelle période
    });
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await repo.setDutyList(_period, _selected!);
      if (mounted) {
        showMessage(
          context,
          'Liste publiée : ${_selected!.length} pharmacie(s) de garde '
          '${formatPeriod(_period.start, _period.end)}.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Publication impossible.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pharmacy>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Chargement impossible',
            text: 'Vérifiez votre connexion Internet.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final selected = _selected ??= {
          for (final p in all)
            if (_overlaps(p)) p.id,
        };
        final items =
            all
                .where(
                  (p) => '${p.name} ${p.address} ${p.city}'
                      .toLowerCase()
                      .contains(_query),
                )
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Card(
                child: ListTile(
                  onTap: _pickPeriod,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  leading: const IconBadge(
                    icon: Icons.date_range_rounded,
                    bg: AppColors.okBg,
                    fg: AppColors.okFg,
                  ),
                  title: Text(
                    'Garde ${formatPeriod(_period.start, _period.end)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Toucher pour changer la période'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _query = v.toLowerCase().trim()),
                decoration: const InputDecoration(
                  hintText: 'Rechercher une pharmacie',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: all.isEmpty
                  ? const EmptyState(
                      icon: Icons.local_pharmacy_outlined,
                      title: 'Annuaire vide',
                      text:
                          'Ajoutez d\'abord les pharmacies dans l\'onglet '
                          '« Pharmacies ».',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final p = items[i];
                        final on = selected.contains(p.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            color: on ? AppColors.okBg : Colors.white,
                            child: CheckboxListTile(
                              value: on,
                              onChanged: (v) => setState(
                                () => v == true
                                    ? selected.add(p.id)
                                    : selected.remove(p.id),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text('${p.address} · ${p.city}'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _busy || all.isEmpty ? null : _publish,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.campaign_rounded),
                  label: Text(
                    _busy
                        ? 'Publication…'
                        : 'Publier la liste (${selected.length})',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
