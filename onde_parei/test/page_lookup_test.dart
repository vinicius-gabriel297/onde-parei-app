import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/api_models.dart';
import 'package:onde_parei/services/api_service.dart';

GoogleBook _edicao(String title, int? pageCount) =>
    GoogleBook(id: title, title: title, pageCount: pageCount);

void main() {
  group('total de páginas entre as edições', () {
    test('a mediana ignora o box que veio junto na busca', () {
      final total = ApiService.pageCountFromEditions('Corte de Espinhos e Rosas', [
        _edicao('Corte de Espinhos e Rosas', 416),
        _edicao('Corte de espinhos e rosas (Vol. 1)', 432),
        _edicao('Corte de Espinhos e Rosas', 465),
      ]);

      expect(total, 432);
    });

    test('box, coleção e resumo não entram na conta', () {
      final total = ApiService.pageCountFromEditions('Duna', [
        _edicao('Duna - Box da trilogia', 1400),
        _edicao('Resumo de Duna', 60),
        _edicao('Duna', 520),
      ]);

      expect(total, 520);
    });

    test('amostra de poucas páginas é descartada', () {
      final total = ApiService.pageCountFromEditions('Duna', [
        _edicao('Duna', 12),
        _edicao('Duna', 520),
      ]);

      expect(total, 520);
    });

    test('obra de outro título não conta, mesmo vindo na resposta', () {
      final total = ApiService.pageCountFromEditions('Duna', [
        _edicao('O Messias de Duna', 380),
        _edicao('Neuromancer', 300),
      ]);

      expect(total, isNull);
    });

    test('sem edição com página utilizável, devolve nulo', () {
      final total = ApiService.pageCountFromEditions('Duna', [
        _edicao('Duna', null),
        _edicao('Duna', 0),
      ]);

      expect(total, isNull);
    });

    test('acento e pontuação não impedem o casamento do título', () {
      final total = ApiService.pageCountFromEditions('Ensaio sobre a Cegueira', [
        _edicao('Ensaio sôbre a cegueira!', 310),
      ]);

      expect(total, 310);
    });
  });
}
