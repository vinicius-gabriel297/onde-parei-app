import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/recap_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recap_card.dart';
import '../../widgets/ui_kit.dart';
import '../items/edit_item_screen.dart';
import 'share_recap_screen.dart';

/// A retrospectiva de leitura: o que a estante conta sobre um ano.
///
/// Lê a mesma coleção de sempre por stream e recalcula tudo em memória a cada
/// troca de ano — `ReadingRecap` é puro e barato, então não há consulta nova
/// por ano nem índice novo no Firestore.
class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  /// Nulo até o primeiro build com dados: o ano inicial é o mais recente que
  /// tem leitura, e isso só dá para saber depois que a estante chega.
  int? _year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Retrospectiva')),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<ItemModel>>(
          stream: user == null
              ? const Stream<List<ItemModel>>.empty()
              : firestore.getUserItems(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Não deu para montar a retrospectiva',
                message: '${snapshot.error}',
              );
            }

            final items = snapshot.data ?? const <ItemModel>[];
            final years = ReadingRecap.availableYears(items);
            // O ano guardado pode ter deixado de existir enquanto a tela está
            // aberta (a última leitura dele foi apagada, por exemplo).
            final year = years.contains(_year) ? _year! : years.first;
            final recap = ReadingRecap.forYear(items, year);
            final pending = items
                .where(
                  (i) => i.status == ReadingStatus.read && i.finishedAt == null,
                )
                .length;

            return Center(
              child: ConstrainedBox(
                // No Web a janela é larga: sem teto, cada cartão vira um bloco
                // gigante e a leitura da tela se perde.
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                if (years.length > 1) ...[
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: years.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final option = years[index];
                        return ChoiceChip(
                          label: Text('$option'),
                          selected: option == year,
                          onSelected: (_) => setState(() => _year = option),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                _HeroCard(recap: recap),

                if (recap.isEmpty) ...[
                  const SizedBox(height: 24),
                  EmptyState(
                    icon: Icons.calendar_month_rounded,
                    title: 'Nenhuma leitura terminada em $year',
                    message: pending > 0
                        ? 'Você tem ${pending == 1 ? 'uma obra lida' : '$pending obras lidas'} '
                              'sem data de conclusão — obras marcadas como '
                              'lidas antes desta versão. Abra cada uma e '
                              'informe quando terminou para elas entrarem na '
                              'retrospectiva.'
                        : 'Assim que você marcar uma obra como lida, ela '
                              'aparece aqui com a data.',
                  ),
                ] else ...[
                  const SizedBox(height: 22),
                  SectionHeader(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                    title: 'Ano a mês',
                    subtitle: recap.busiestMonth == null
                        ? null
                        : 'Mês mais forte: ${monthName(recap.busiestMonth!)}',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: SizedBox(
                      height: 150,
                      child: MonthBars(recap: recap),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const SectionHeader(
                    padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
                    title: 'Cápsula de cada mês',
                    subtitle: 'Cada mês tem a sua, e compartilha sozinha',
                  ),
                  const SizedBox(height: 4),
                  for (final month in ReadingRecap.monthsWithReadings(
                    items,
                    year,
                  ))
                    _MonthCapsule(
                      recap: ReadingRecap.forMonth(items, year, month),
                      readerName: user?.displayName ?? '',
                    ),

                  const SizedBox(height: 24),
                  const SectionHeader(
                    padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
                    title: 'Números do ano',
                  ),
                  const SizedBox(height: 4),
                  _NumbersGrid(recap: recap),

                  if (recap.topGenres.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SectionHeader(
                      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                      title: 'Gêneros favoritos',
                      subtitle: 'O que você mais leu em $year',
                    ),
                    const SizedBox(height: 8),
                    _GenreBars(genres: recap.topGenres),
                  ],

                  if (recap.favorite != null) ...[
                    const SizedBox(height: 24),
                    const SectionHeader(
                      padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
                      title: 'A melhor do ano',
                      subtitle: 'A obra que recebeu sua maior nota',
                    ),
                    const SizedBox(height: 8),
                    _FavoriteTile(item: recap.favorite!),
                  ],

                  const SizedBox(height: 24),
                  SectionHeader(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                    title: 'Tudo que terminou',
                    subtitle: recap.total == 1
                        ? '1 obra'
                        : '${recap.total} obras',
                  ),
                  const SizedBox(height: 4),
                  for (final item in recap.finished)
                    _FinishedTile(item: item),

                  if (pending > 0) ...[
                    const SizedBox(height: 18),
                    Text(
                      pending == 1
                          ? 'Uma obra lida ficou de fora por não ter data de '
                                'conclusão. Abra o título e informe quando '
                                'terminou.'
                          : '$pending obras lidas ficaram de fora por não ter '
                                'data de conclusão. Abra cada título e informe '
                                'quando terminou.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],

                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: () => openShareRecap(
                      context,
                      recap: recap,
                      readerName: user?.displayName ?? '',
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Compartilhar retrospectiva'),
                  ),
                ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Destaque ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final ReadingRecap recap;

  const _HeroCard({required this.recap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final isCurrentYear = recap.year == now.year;
    final thisMonth = isCurrentYear ? recap.countIn(now.month) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${recap.total}',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recap.total == 1
                      ? 'obra terminada em ${recap.year}'
                      : 'obras terminadas em ${recap.year}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (thisMonth != null) ...[
            const SizedBox(height: 12),
            Text(
              thisMonth == 0
                  ? 'Nenhuma em ${monthName(now.month)} até agora.'
                  : thisMonth == 1
                  ? '1 delas em ${monthName(now.month)}.'
                  : '$thisMonth delas em ${monthName(now.month)}.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Cápsula mensal ───────────────────────────────────────────────────────────

/// Um mês do ano em formato de cartão, no espírito da cápsula do Spotify: o
/// número, o destaque e um atalho para compartilhar só aquele mês.
class _MonthCapsule extends StatelessWidget {
  final ReadingRecap recap;
  final String readerName;

  const _MonthCapsule({required this.recap, required this.readerName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final favorite = recap.favorite;
    // Sem nota em nenhuma obra do mês, o destaque vira a última terminada —
    // um cartão sem nada além do número diz pouco.
    final destaque =
        favorite ?? (recap.finished.isEmpty ? null : recap.finished.first);
    final mes = monthName(recap.month!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${mes[0].toUpperCase()}${mes.substring(1)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${recap.total}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            recap.total == 1 ? 'obra' : 'obras',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (recap.pages > 0)
                        Text(
                          '${recap.pages} páginas',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (recap.chapters > 0)
                        Text(
                          '${recap.chapters} capítulos',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (recap.averageRating > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              recap.averageRating.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (destaque != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CoverArt(
                          imageUrl: destaque.imageUrl,
                          title: destaque.name,
                          width: 26,
                          height: 39,
                          decodeWidth: 80,
                          fallbackIcon: destaque.type.isBook
                              ? Icons.menu_book_rounded
                              : Icons.import_contacts_rounded,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            favorite == null
                                ? destaque.name
                                : 'Destaque: ${destaque.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Compartilhar $mes',
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              onPressed: () =>
                  openShareRecap(context, recap: recap, readerName: readerName),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Números ──────────────────────────────────────────────────────────────────

class _NumbersGrid extends StatelessWidget {
  final ReadingRecap recap;

  const _NumbersGrid({required this.recap});

  @override
  Widget build(BuildContext context) {
    final average = recap.averageDays;

    final cells = <(String, String, Color)>[
      ('${recap.books}', recap.books == 1 ? 'livro' : 'livros',
          AppColors.typeBook),
      (
        '${recap.comics}',
        recap.comics == 1 ? 'quadrinho' : 'quadrinhos',
        AppColors.typeManga,
      ),
      (
        recap.pages > 0 ? '${recap.pages}' : '—',
        'páginas',
        AppColors.terracotta,
      ),
      (
        recap.chapters > 0 ? '${recap.chapters}' : '—',
        'capítulos',
        AppColors.statusWant,
      ),
      (
        recap.averageRating > 0 ? recap.averageRating.toStringAsFixed(1) : '—',
        'nota média',
        AppColors.gold,
      ),
      (
        average == null ? '—' : '${average.round()}',
        'dias por obra',
        AppColors.statusPaused,
      ),
    ];

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Altura fixa e largura com teto: a proporção livre fazia a célula
      // crescer junto com a janela e virar um retângulo vazio no desktop.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 86,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      children: [
        for (final (value, label, color) in cells)
          _NumberCell(value: value, label: label, color: color),
      ],
    );
  }
}

class _NumberCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _NumberCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ─── Gêneros ──────────────────────────────────────────────────────────────────

class _GenreBars extends StatelessWidget {
  final List<GenreCount> genres;

  const _GenreBars({required this.genres});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = genres.first.count;

    return Column(
      children: [
        for (final genre in genres)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    genre.genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: ReadingProgressBar(
                    value: genre.count / peak,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 22,
                  child: Text(
                    '${genre.count}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Obras ────────────────────────────────────────────────────────────────────

class _FavoriteTile extends StatelessWidget {
  final ItemModel item;

  const _FavoriteTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => EditItemScreen(item: item)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              CoverArt(
                imageUrl: item.imageUrl,
                title: item.name,
                width: 56,
                height: 84,
                decodeWidth: 140,
                fallbackIcon: item.type.isBook
                    ? Icons.menu_book_rounded
                    : Icons.import_contacts_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if ((item.author ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        TypeBadge.forItem(item, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishedTile extends StatelessWidget {
  final ItemModel item;

  const _FinishedTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = item.readingDays;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EditItemScreen(item: item)),
      ),
      leading: CoverArt(
        imageUrl: item.imageUrl,
        title: item.name,
        width: 38,
        height: 56,
        decodeWidth: 100,
        fallbackIcon: item.type.isBook
            ? Icons.menu_book_rounded
            : Icons.import_contacts_rounded,
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        days == null
            ? formatFullDate(item.finishedAt!)
            : '${formatFullDate(item.finishedAt!)} · '
                  '${days == 1 ? '1 dia' : '$days dias'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: item.rating > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  item.rating.toStringAsFixed(1),
                  style: theme.textTheme.labelMedium,
                ),
              ],
            )
          : null,
    );
  }
}
