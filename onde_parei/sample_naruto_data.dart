// Arquivo com dados de exemplo do Naruto para teste
// Estes dados foram obtidos da API Jikan em 08/10/2025

final List<Map<String, dynamic>> sampleNarutoData = [
  {
    'mal_id': 11,
    'title': 'Naruto',
    'images': {
      'jpg': {
        'large_image_url': 'https://cdn.myanimelist.net/images/manga/3/249658l.jpg'
      }
    },
    'synopsis': 'Whenever Naruto Uzumaki proclaims that he will someday become the Hokage—a title bestowed upon the best ninja in the Village Hidden in the Leaves—no one takes him seriously. After all, Naruto is the carrier of Kurama, the Nine-Tails fox spirit that nearly destroyed the village 12 years ago. Mocked for his appearance, he lives as an outcast, treated with contempt by the villagers. But one day, Naruto discovers that he has the spirit of a ninja from a previous generation living inside of him. With the help of this spirit and his mentor Jiraiya, Naruto trains to become the strongest ninja in the village and earn the respect of his peers.',
    'authors': [
      {'name': 'Kishimoto, Masashi'}
    ],
    'status': 'Finished',
    'volumes': 72,
    'chapters': 700,
  },
  {
    'mal_id': 6444,
    'title': 'Naruto',
    'images': {
      'jpg': {
        'large_image_url': 'https://cdn.myanimelist.net/images/manga/1/125935l.jpg'
      }
    },
    'synopsis': 'A one-shot manga by Kishimoto that debuted in Akamaru Jump in 1997.',
    'authors': [
      {'name': 'Kishimoto, Masashi'}
    ],
    'status': 'Finished',
    'volumes': null,
    'chapters': 1,
  },
  {
    'mal_id': 95210,
    'title': 'Boruto: Naruto Next Generations',
    'images': {
      'jpg': {
        'large_image_url': 'https://cdn.myanimelist.net/images/manga/3/181968l.jpg'
      }
    },
    'synopsis': 'The ninja adventures continue with Naruto\'s son, Boruto! Naruto was a young shinobi with an incorrigible knack for mischief. He achieved his dream to become the greatest ninja in his village, and now his face sits atop the Hokage monument. But this is not his story... A new generation of ninja is ready to take the stage, led by Naruto\'s own son, Boruto!',
    'authors': [
      {'name': 'Kishimoto, Masashi'},
      {'name': 'Ikemoto, Mikio'},
      {'name': 'Kodachi, Ukyou'}
    ],
    'status': 'Finished',
    'volumes': 20,
    'chapters': 81,
  },
  {
    'mal_id': 87866,
    'title': 'Naruto Gaiden: Nanadaime Hokage to Akairo no Hanatsuzuki',
    'images': {
      'jpg': {
        'large_image_url': 'https://cdn.myanimelist.net/images/manga/2/161762l.jpg'
      }
    },
    'synopsis': 'Naruto Gaiden: The Seventh Hokage and the Scarlet Spring is a spin-off manga that reveals what happens between the epilogue of Naruto and the events of Boruto: Naruto Next Generations.',
    'authors': [
      {'name': 'Kishimoto, Masashi'}
    ],
    'status': 'Finished',
    'volumes': 1,
    'chapters': 10,
  },
  {
    'mal_id': 90531,
    'title': 'Naruto Shinden Series',
    'images': {
      'jpg': {
        'large_image_url': 'https://cdn.myanimelist.net/images/manga/2/190847l.jpg'
      }
    },
    'synopsis': 'A series of novels set in the Naruto universe.',
    'authors': [
      {'name': 'Kishimoto, Masashi'},
      {'name': 'Yano, Takashi'},
      {'name': 'Towada, Shin'}
    ],
    'status': 'Finished',
    'volumes': 3,
    'chapters': 11,
  },
];

void main() {
  print('📚 Dados de exemplo do Naruto:');
  print('Total de itens: ${sampleNarutoData.length}');

  for (int i = 0; i < sampleNarutoData.length; i++) {
    final manga = sampleNarutoData[i];
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Manga #${i + 1}: ${manga['title']}');
    print('MAL ID: ${manga['mal_id']}');
    print('Status: ${manga['status']}');
    print('Volumes: ${manga['volumes']}');
    print('Capitulos: ${manga['chapters']}');
    print('Autores: ${manga['authors'].map((a) => a['name']).join(', ')}');
  }

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ Dados prontos para uso no aplicativo!');
}
