import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Iniciando teste da API Jikan para Naruto...');

  try {
    final url = 'https://api.jikan.moe/v4/manga?q=Naruto&limit=5';

    print('Fazendo requisicao para: $url');

    final response = await http.get(
      Uri.parse(url),
    ).timeout(const Duration(seconds: 10));

    print('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print('Dados recebidos:');
      print('Total de mangas encontrados: ${data['data'].length}');

      for (int i = 0; i < data['data'].length; i++) {
        final manga = data['data'][i];
        print('Manga #${i + 1}:');
        print('  Titulo: ${manga['title']}');
        print('  MAL ID: ${manga['mal_id']}');
        print('  Imagem: ${manga['images']['jpg']['large_image_url']}');
        print('  Autores: ${manga['authors']?.map((a) => a['name']).join(', ')}');
        print('  Status: ${manga['status']}');
        print('  Volumes: ${manga['volumes']}');
        print('  Capitulos: ${manga['chapters']}');
        print('---');
      }

      print('Teste concluido com sucesso!');

    } else {
      print('Erro na API:');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
    }

  } catch (e) {
    print('Erro durante o teste: $e');
  }

  print('Teste finalizado');
}
