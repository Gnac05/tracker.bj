import 'package:flutter/material.dart';

import '../models.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// Signalements des utilisateurs à certifier ou rejeter.
class ReportsAdminTab extends StatefulWidget {
  const ReportsAdminTab({super.key});

  @override
  State<ReportsAdminTab> createState() => _ReportsAdminTabState();
}

class _ReportsAdminTabState extends State<ReportsAdminTab> {
  ReportStatus _status = ReportStatus.pending;
  late Stream<List<FuelReport>> _stream = repo.watchReports(_status);
  final _busy = <String>{};

  void _setStatus(ReportStatus s) => setState(() {
    _status = s;
    _stream = repo.watchReports(s);
  });

  Future<void> _review(FuelReport r, bool approve) async {
    setState(() => _busy.add(r.id));
    try {
      await repo.reviewReport(r, approve: approve);
      if (mounted) {
        showMessage(
          context,
          approve
              ? '${r.stationName} : ${r.hasFuel ? 'essence disponible' : 'pas d\'essence'} (certifié)'
              : 'Signalement rejeté.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Action impossible. Réessayez.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ReportStatus>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ReportStatus.pending,
                  label: Text('En attente'),
                ),
                ButtonSegment(
                  value: ReportStatus.approved,
                  label: Text('Certifiés'),
                ),
                ButtonSegment(
                  value: ReportStatus.rejected,
                  label: Text('Rejetés'),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (s) => _setStatus(s.first),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FuelReport>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return const EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Chargement impossible',
                  text: 'Vérifiez la connexion et vos droits administrateur.',
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.inbox_rounded,
                  title: _status == ReportStatus.pending
                      ? 'Tout est traité'
                      : 'Aucun signalement',
                  text: _status == ReportStatus.pending
                      ? 'Aucun signalement en attente de certification.'
                      : 'Rien à afficher dans cette catégorie.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ReportCard(
                  report: items[i],
                  busy: _busy.contains(items[i].id),
                  onReview: (ok) => _review(items[i], ok),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onReview,
  });

  final FuelReport report;
  final bool busy;
  final ValueChanged<bool> onReview;

  Widget _photo({BoxFit fit = BoxFit.cover}) {
    if (report.photoBytes != null) {
      return Image.memory(report.photoBytes!, fit: fit);
    }
    if (report.photoUrl != null) {
      return Image.network(
        report.photoUrl!,
        fit: fit,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, _, _) => const _NoPhoto('Photo illisible'),
      );
    }
    return const _NoPhoto('Pas de photo (exemple de démo)');
  }

  @override
  Widget build(BuildContext context) {
    final d = report.distanceMeters;
    final far = d == null || d > 500;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                insetPadding: const EdgeInsets.all(12),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(child: _photo(fit: BoxFit.contain)),
              ),
            ),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: _photo(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.stationName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Signalé ${timeAgo(report.createdAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Pill.fuel(
                      report.hasFuel
                          ? FuelStatus.available
                          : FuelStatus.unavailable,
                    ),
                    Pill(
                      label: d == null
                          ? 'Position inconnue'
                          : 'Pris à ${formatDistance(d)} de la station',
                      bg: far ? AppColors.waitBg : AppColors.neutralBg,
                      fg: far ? AppColors.waitFg : AppColors.muted,
                      icon: far
                          ? Icons.warning_amber_rounded
                          : Icons.place_rounded,
                    ),
                  ],
                ),
                if (report.status == ReportStatus.pending) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : () => onReview(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.koFg,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          label: const Text('Rejeter'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => onReview(true),
                          icon: const Icon(Icons.verified_rounded, size: 20),
                          label: const Text('Certifier'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutralBg,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.muted,
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
