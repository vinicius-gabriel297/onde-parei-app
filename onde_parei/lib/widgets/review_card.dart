import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../models/item_model.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// O card que vira imagem no compartilhamento.
///
/// Widget puro — sem I/O, sem `context.read` — para poder ser montado num teste
/// de widget e capturado sem surpresa de layout. O tamanho é **fixo** em
/// [width] x [height] lógicos: capturado com `pixelRatio: 2` sai em 1080x1350,
/// que é a proporção 4:5 de feed. Quem exibe o card na tela usa `FittedBox`
/// para caber, em vez de mudar essas medidas.
class ShareReviewCard extends StatelessWidget {
  static const double width = 540;
  static const double height = 675;

  final ItemModel item;

  /// Capa já resolvida (a original ou a variante pelo proxy). Vem de fora
  /// porque a captura precisa da imagem já em cache — ver `ShareReviewScreen`.
  final String? coverUrl;

  const ShareReviewCard({super.key, required this.item, this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final review = item.review.trim();

    // O card tem medidas fixas: a escala de fonte do sistema não pode entrar
    // aqui, senão o texto estoura o PNG em quem usa fonte grande.
    return MediaQuery.withNoTextScaling(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surface,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                AppColors.gold.withValues(alpha: 0.10),
                scheme.surface,
              ),
              scheme.surface,
            ],
            stops: const [0, 0.55],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(34, 32, 34, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sem review, o cabeçalho fica centrado entre o topo e o rodapé
            // — um card só com nota não pode virar um bloco no alto e um
            // vazio embaixo. Este `Spacer` faz par com o `Expanded` de baixo.
            if (review.isEmpty) const Spacer(),
            _Header(item: item, coverUrl: coverUrl),
            if (review.isNotEmpty) ...[
              const SizedBox(height: 22),
              Divider(height: 1, color: scheme.outlineVariant),
            ],
            // O review fica centrado no espaço que sobra: assim um texto de
            // duas linhas não deixa metade do card vazia, e um texto longo
            // continua ocupando o mesmo bloco.
            Expanded(
              child: review.isEmpty
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '“$review”',
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 17,
                          height: 1.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ItemModel item;
  final String? coverUrl;

  const _Header({required this.item, this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 225,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CoverArt(
              imageUrl: coverUrl,
              title: item.name,
              width: 150,
              height: 225,
              decodeWidth: 320,
              fallbackIcon: item.type.isBook
                  ? Icons.menu_book_rounded
                  : Icons.import_contacts_rounded,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    TypeBadge.forItem(item),
                    StatusPill(status: item.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 27,
                    height: 1.2,
                  ),
                ),
                if ((item.author ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                ],
                if (item.rating > 0) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // `scheme.primary` em vez de `AppColors.gold` fixo: no
                      // tema claro o dourado claro sobre papel quase some, e
                      // aqui a imagem sai do app — tem que ler bem nos dois.
                      RatingBarIndicator(
                        rating: item.rating,
                        itemCount: 5,
                        itemSize: 25,
                        unratedColor: scheme.outlineVariant,
                        itemBuilder: (_, __) => Icon(
                          Icons.star_rounded,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          color: scheme.primary,
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

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.auto_stories_rounded, size: 19, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          'Onde Parei?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 15,
            color: scheme.primary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            'onde-parei-ea32c.web.app',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
