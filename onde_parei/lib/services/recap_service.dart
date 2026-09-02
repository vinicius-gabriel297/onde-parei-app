import '../models/item_model.dart';

/// Um gênero e quantas obras dele foram terminadas no período.
class GenreCount {
  final String genre;
  final int count;

  const GenreCount(this.genre, this.count);
}

/// A retrospectiva de um período: o que a estante conta sobre as leituras que
/// encerraram dentro dele. O período é um ano inteiro ou um único mês — a
/// cápsula mensal e a do ano são o mesmo objeto, só muda o recorte.
///
/// Objeto puro, montado por [ReadingRecap.forYear] a partir da lista que a tela
/// já tem em mãos — não faz I/O e não conhece o Firestore, então dá para testar
/// e para recalcular a cada troca de ano sem custo de rede.
///
/// "Terminado" aqui é sempre *status lido* **e** [ItemModel.finishedAt] dentro
/// do ano. Item lido antes desta versão não tem data e por isso fica de fora:
/// é preferível um ano vazio a um ano inventado a partir de `updatedAt`.
class ReadingRecap {
  final int year;

  /// O mês do recorte (1..12), ou nulo quando a retrospectiva é do ano todo.
  final int? month;

  /// As obras terminadas no ano, da mais recente para a mais antiga.
  final List<ItemModel> finished;

  /// Quantas terminaram em cada mês — índice 0 é janeiro.
  final List<int> byMonth;

  final int books;
  final int comics;

  /// Páginas e capítulos somados, contando só obra com total informado.
  final int pages;
  final int chapters;

  /// Média das notas dadas às obras do ano (só as que receberam nota).
  final double averageRating;
  final int ratedCount;

  final List<GenreCount> topGenres;

  /// A melhor do ano: maior nota, desempate pela mais recente. Nulo quando
  /// nenhuma obra do ano recebeu nota.
  final ItemModel? favorite;

  /// Média de dias entre começar e terminar, entre as obras que têm as duas
  /// datas. Nulo quando nenhuma tem.
  final double? averageDays;

  const ReadingRecap({
    required this.year,
    required this.month,
    required this.finished,
    required this.byMonth,
    required this.books,
    required this.comics,
    required this.pages,
    required this.chapters,
    required this.averageRating,
    required this.ratedCount,
    required this.topGenres,
    required this.favorite,
    required this.averageDays,
  });

  int get total => finished.length;

  bool get isEmpty => finished.isEmpty;

  /// Recorte de um mês só, e não do ano inteiro.
  bool get isMonthly => month != null;

  /// Como o período se escreve: `setembro de 2026` ou `2026`.
  String get periodLabel =>
      isMonthly ? '${monthName(month!)} de $year' : '$year';

  /// O mês mais cheio do ano (1..12), ou nulo se o ano não teve leitura.
  int? get busiestMonth {
    if (isEmpty) return null;
    var best = 0;
    for (var i = 1; i < byMonth.length; i++) {
      if (byMonth[i] > byMonth[best]) best = i;
    }
    return byMonth[best] == 0 ? null : best + 1;
  }

  /// Quantas terminaram em [month] (1..12).
  int countIn(int month) => byMonth[month - 1];

  /// Uma obra conta para o período quando foi lida **e** tem data de fim
  /// conhecida dentro dele.
  static bool _countsFor(ItemModel item, int year, int? month) =>
      item.status == ReadingStatus.read &&
      item.finishedAt != null &&
      item.finishedAt!.year == year &&
      (month == null || item.finishedAt!.month == month);

  /// Os anos que têm algo para mostrar, do mais recente para o mais antigo.
  /// Sempre inclui o ano corrente, para a tela nunca abrir sem nenhuma opção.
  static List<int> availableYears(List<ItemModel> items, {DateTime? now}) {
    final years = <int>{(now ?? DateTime.now()).year};
    for (final item in items) {
      if (item.status == ReadingStatus.read && item.finishedAt != null) {
        years.add(item.finishedAt!.year);
      }
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Os meses de [year] que têm leitura, do mais recente para o mais antigo —
  /// a ordem em que as cápsulas mensais aparecem na tela.
  static List<int> monthsWithReadings(List<ItemModel> items, int year) {
    final months = <int>{};
    for (final item in items) {
      if (_countsFor(item, year, null)) months.add(item.finishedAt!.month);
    }
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  factory ReadingRecap.forYear(List<ItemModel> items, int year) =>
      ReadingRecap.forPeriod(items, year);

  /// A cápsula de um mês só.
  factory ReadingRecap.forMonth(List<ItemModel> items, int year, int month) =>
      ReadingRecap.forPeriod(items, year, month: month);

  factory ReadingRecap.forPeriod(
    List<ItemModel> items,
    int year, {
    int? month,
  }) {
    final finished = items.where((i) => _countsFor(i, year, month)).toList()
      ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));

    final byMonth = List<int>.filled(12, 0);
    final genreCounts = <String, int>{};

    var books = 0;
    var comics = 0;
    var pages = 0;
    var chapters = 0;
    var totalRating = 0.0;
    var ratedCount = 0;
    var daysSum = 0;
    var daysCount = 0;
    ItemModel? favorite;

    for (final item in finished) {
      byMonth[item.finishedAt!.month - 1]++;

      if (item.type.isBook) {
        books++;
      } else {
        comics++;
      }

      final total = item.totalValue;
      if (total != null && total > 0) {
        if (item.type.countsChapters) {
          chapters += total;
        } else {
          pages += total;
        }
      }

      if (item.rating > 0) {
        totalRating += item.rating;
        ratedCount++;
        // `finished` já vem do mais recente para o mais antigo, então o `>`
        // deixa o empate com a leitura mais nova — que é a que o usuário
        // lembra melhor.
        if (favorite == null || item.rating > favorite.rating) favorite = item;
      }

      final days = item.readingDays;
      if (days != null) {
        daysSum += days;
        daysCount++;
      }

      for (final genre in item.genres ?? const <String>[]) {
        final key = genre.trim();
        if (key.isEmpty) continue;
        genreCounts[key] = (genreCounts[key] ?? 0) + 1;
      }
    }

    final topGenres =
        genreCounts.entries.map((e) => GenreCount(e.key, e.value)).toList()
          // Empate resolvido pelo nome, para a lista não dançar entre builds.
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            return byCount != 0 ? byCount : a.genre.compareTo(b.genre);
          });

    return ReadingRecap(
      year: year,
      month: month,
      finished: finished,
      byMonth: byMonth,
      books: books,
      comics: comics,
      pages: pages,
      chapters: chapters,
      averageRating: ratedCount > 0 ? totalRating / ratedCount : 0,
      ratedCount: ratedCount,
      topGenres: topGenres.take(5).toList(),
      favorite: favorite,
      averageDays: daysCount > 0 ? daysSum / daysCount : null,
    );
  }
}

const _monthNames = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Nome do mês (1..12) em minúsculas — o texto de tela decide a maiúscula.
String monthName(int month) => _monthNames[month - 1];

/// Abreviação de três letras, usada nos rótulos do gráfico.
String monthAbbr(int month) {
  final name = _monthNames[month - 1];
  return '${name[0].toUpperCase()}${name.substring(1, 3)}';
}

/// Data curta, do jeito que se escreve aqui: `4 de março de 2026`.
String formatFullDate(DateTime date) =>
    '${date.day} de ${monthName(date.month)} de ${date.year}';

/// `04/03/2026` — para caber em espaço apertado.
String formatShortDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
