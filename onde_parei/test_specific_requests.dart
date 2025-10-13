import 'dart:convert';
import 'package:http/http.dart' as http;

// Teste específico para Naruto (Jikan API)
Future<dynamic> testNarutoAPI() async {
  print('🧪 Testando API Jikan para "Naruto"...');

  try {
    final url = 'https://api.jikan.moe/v4/manga?q=Naruto&limit=3';

    print('📡 Fazendo requisição para: $url');

    final response = await http.get(
      Uri.parse(url),
    ).timeout(const Duration(seconds: 10));

    print('📊 Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print('✅ Naruto API funcionando!');
      print('📚 Mangás encontrados: ${data['data'].length}');

      for (int i = 0; i < data['data'].length; i++) {
        final manga = data['data'][i];
        print('  ${i + 1}. ${manga['title']} (MAL ID: ${manga['mal_id']})');
      }

      return data['data'];

    } else {
      print('❌ Erro na API Naruto: ${response.statusCode}');
      return null;
    }

  } catch (e) {
    print('🚨 Erro no teste Naruto: $e');
    return null;
  }
}

// Teste específico para Verity (Google Books API)
Future<dynamic> testVerityAPI() async {
  print('🧪 Testando API Google Books para "Verity"...');

  try {
    final url = 'https://www.googleapis.com/books/v1/volumes?q=Verity&maxResults=3';

    print('📡 Fazendo requisição para: $url');

    final response = await http.get(
      Uri.parse(url),
    ).timeout(const Duration(seconds: 10));

    print('📊 Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print('✅ Verity API funcionando!');
      print('📚 Livros encontrados: ${data['items'].length}');

      for (int i = 0; i < data['items'].length; i++) {
        final book = data['items'][i];
        final volumeInfo = book['volumeInfo'];
        print('  ${i + 1}. ${volumeInfo['title']} (${volumeInfo['authors']?.join(', ')})');
      }

      return data['items'];

    } else {
      print('❌ Erro na API Verity: ${response.statusCode}');
      return null;
    }

  } catch (e) {
    print('🚨 Erro no teste Verity: $e');
    return null;
  }
}

void main() async {
  print('🚀 Iniciando testes específicos das APIs...');
  print('');

  // Testar Naruto
  final narutoResults = await testNarutoAPI();
  print('');

  // Testar Verity
  final verityResults = await testVerityAPI();
  print('');

  // Resumo
  print('📋 RESUMO DOS TESTES:');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  if (narutoResults != null) {
    print('✅ Naruto (Jikan API): ${narutoResults.length} resultados');
  } else {
    print('❌ Naruto (Jikan API): Falhou');
  }

  if (verityResults != null) {
    print('✅ Verity (Google Books API): ${verityResults.length} resultados');
  } else {
    print('❌ Verity (Google Books API): Falhou');
  }

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  if (narutoResults != null && verityResults != null) {
    print('🎉 Ambas as APIs funcionando perfeitamente!');
    print('💡 Pronto para aplicar no aplicativo');
  } else {
    print('⚠️ Alguma API com problemas - verificar antes de aplicar');
  }

  print('🔚 Testes finalizados');
}
