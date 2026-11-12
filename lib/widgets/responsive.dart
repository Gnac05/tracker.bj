import 'package:flutter/material.dart';

/// Largeur à partir de laquelle on passe à la mise en page « grand écran »
/// (tablette en paysage, ordinateur).
const kWideBreakpoint = 720.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Largeur maximale des feuilles du bas sur grand écran.
const sheetConstraints = BoxConstraints(maxWidth: 640);

/// Ouvre un écran secondaire : page plein écran sur téléphone, fenêtre
/// centrée sur grand écran (l'écran garde sa barre de titre et son bouton
/// retour, qui ferme la fenêtre).
Future<T?> openPage<T>(BuildContext context, Widget page) {
  if (!isWide(context)) {
    return Navigator.of(context)
        .push<T>(MaterialPageRoute(builder: (_) => page));
  }
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 800),
        child: page,
      ),
    ),
  );
}

/// Centre le contenu et limite sa largeur sur grand écran.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 880});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Liste de cartes : une colonne sur téléphone, de 2 à 4 colonnes selon la
/// largeur disponible. L'ordre de lecture reste de gauche à droite puis de
/// haut en bas (important pour un classement par distance).
class SliverCardGrid extends StatelessWidget {
  const SliverCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minCardWidth = 320,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.crossAxisExtent / minCardWidth).floor().clamp(
          1,
          4,
        );
        if (cols == 1) {
          return SliverList.separated(
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: itemBuilder,
          );
        }
        return SliverList.separated(
          itemCount: (itemCount / cols).ceil(),
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, row) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: 16),
                  Expanded(
                    child: row * cols + c < itemCount
                        ? itemBuilder(context, row * cols + c)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
