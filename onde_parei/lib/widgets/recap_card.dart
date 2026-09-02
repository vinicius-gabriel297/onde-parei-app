import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../services/recap_service.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// As doze colunas do ano — quantas obras terminaram em cada mês.
///
/// Pública porque o card de compartilhamento e a tela da retrospectiva mostram
/// exatamente o mesmo gráfico; só muda a largura da coluna.
class MonthBars extends StatelessWidget {
  final ReadingRecap recap;
  final double barWidth;

  const MonthBars({super.key, required this.recap, this.barWidth = 18});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // O mês mais cheio define a escala; o piso de 1 evita divisão por zero no
    // ano ainda vazio.
    final peak = recap.byMonth.fold<int>(1, (max, v) => v > max ? v : max);
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var month = 1; month <= 12; month++)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (recap.countIn(month) > 0)
                  Text(
                    '${recap.countIn(month)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                const SizedBox(height: 3),
                Expanded(
                  child: FractionallySizedBox(
                    // Coluna vazia vira um traço fino, para o eixo continuar
                    // legível em mês sem leitura.
                    heightFactor: recap.countIn(month) == 0
                        ? 0.04
                        : (recap.countIn(month) / peak).clamp(0.12, 1.0),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: barWidth,
                      decoration: BoxDecoration(
                        color: recap.countIn(month) == 0
                            ? scheme.outlineVariant
                            : scheme.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  monthAbbr(month),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight:
                        (recap.year == currentYear && month == currentMonth)
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A retrospectiva do ano virando imagem.
///
/// Mesmas regras do `ShareReviewCard`: widget puro, sem I/O, tamanho **fixo**
/// em [width] x [height] lógicos — capturado com `pixelRatio: 2` sai em
/// 1080x1350, a proporção 4:5 de feed. Quem mostra na tela usa `FittedBox`.
class RecapCard extends StatelessWidget {
  static const double width = 540;
  static const double height = 675;

  final ReadingRecap recap;

  /// Nome de quem leu, escrito no topo. Vazio some.
  final String readerName;

  /// Capa da obra favorita, já resolvida e em cache — a captura não espera
  /// download (ver `ShareRecapScreen`).
  final String? favoriteCoverUrl;

  const RecapCard({
    super.key,
    required this.recap,
    this.readerName = '',
    this.favoriteCoverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final favorite = recap.favorite;
    final name = readerName.trim();

    // Medidas fixas: a escala de fonte do sistema não pode entrar aqui, senão
    // o texto estoura o PNG em quem usa fonte grande.
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
                AppColors.gold.withValues(alpha: 0.14),
                scheme.surface,
              ),
              scheme.surface,
            ],
            stops: const [0, 0.6],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty
                  ? (recap.isMonthly
                        ? 'Cápsula de ${recap.periodLabel}'
                        : 'Retrospectiva ${recap.year}')
                  : (recap.isMonthly
                        ? 'A cápsula de $name'
                        : 'A retrospectiva de $name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 15,
                letterSpacing: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${recap.total}',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 76,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recap.total == 1
                        ? 'obra terminada em ${recap.periodLabel}'
                        : 'obras terminadas em ${recap.periodLabel}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 19,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            Row(
              children: [
                _Stat(
                  value: '${recap.books}',
                  label: recap.books == 1 ? 'livro' : 'livros',
                  color: AppColors.typeBook,
                ),
                _Stat(
                  value: '${recap.comics}',
                  label: recap.comics == 1 ? 'quadrinho' : 'quadrinhos',
                  color: AppColors.typeManga,
                ),
                _Stat(
                  value: recap.pages > 0 ? '${recap.pages}' : '—',
                  label: 'páginas',
                  color: AppColors.terracotta,
                ),
                _Stat(
                  value: recap.averageRating > 0
                      ? recap.averageRating.toStringAsFixed(1)
                      : '—',
                  label: 'nota média',
                  color: AppColors.gold,
                ),
              ],
            ),

            const SizedBox(height: 22),
            // Doze colunas não dizem nada sobre um mês só — ali o espaço vale
            // mais mostrando o que foi lido.
            // A lista pede um pouco mais de altura que o gráfico: três linhas
            // mais o resumo do resto não cabem em 96.
            SizedBox(
              height: recap.isMonthly ? 112 : 96,
              child: recap.isMonthly
                  ? _FinishedList(recap: recap)
                  : MonthBars(recap: recap, barWidth: 20),
            ),

            const SizedBox(height: 18),
            Divider(height: 1, color: scheme.outlineVariant),

            // O que sobra vai para o favorito e os gêneros — centrados juntos,
            // para o card não abrir um buraco quando falta um dos dois.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (favorite != null) ...[
                    Text(
                      recap.isMonthly ? 'A MELHOR DO MÊS' : 'A MELHOR DO ANO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CoverArt(
                          imageUrl: favoriteCoverUrl,
                          title: favorite.name,
                          width: 62,
                          height: 93,
                          decodeWidth: 160,
                          fallbackIcon: favorite.type.isBook
                              ? Icons.menu_book_rounded
                              : Icons.import_contacts_rounded,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                favorite.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 20,
                                  height: 1.2,
                                ),
                              ),
                              if ((favorite.author ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  favorite.author!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  // `scheme.primary` em vez do dourado fixo: no
                                  // tema claro ele quase some no papel, e esta
                                  // imagem sai do app.
                                  Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    favorite.rating.toStringAsFixed(1),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontSize: 15,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (recap.topGenres.isNotEmpty) ...[
                    if (favorite != null) const SizedBox(height: 18),
                    Text(
                      recap.isMonthly ? 'GÊNEROS DO MÊS' : 'GÊNEROS DO ANO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final genre in recap.topGenres.take(4))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Text(
                              '${genre.genre} · ${genre.count}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 10),
            const ShareCardFooter(),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Os títulos do mês, no lugar que o gráfico ocupa na cápsula do ano. Mostra
/// os primeiros e resume o resto em uma linha, para não estourar a altura fixa.
class _FinishedList extends StatelessWidget {
  final ReadingRecap recap;

  const _FinishedList({required this.recap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const visible = 3;
    final restantes = recap.total - visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in recap.finished.take(visible))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: scheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                ),
                if (item.rating > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.rating.toStringAsFixed(1),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (restantes > 0)
          Text(
            restantes == 1 ? 'e mais uma' : 'e mais $restantes',
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 12),
          ),
      ],
    );
  }
}
