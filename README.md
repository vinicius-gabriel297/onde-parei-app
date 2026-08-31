# 📚 Onde Parei?

App Flutter para acompanhar **onde você parou** em cada livro, mangá, manhwa e manhua.
Busca integrada em cinco catálogos, estante pessoal sincronizada no Firebase e
progresso de leitura por capítulo ou página.

🌐 **Online:** https://onde-parei-ea32c.web.app (instalável como app no celular)

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

---

## ✨ O que o app faz

- 🔐 **Login e cadastro** com Firebase Auth
- 🔎 **Busca progressiva** em MangaDex, Kitsu, MyAnimeList, Google Books e Open Library
  ao mesmo tempo — os resultados aparecem conforme cada fonte responde
- 📖 **Estante pessoal** com capas, filtros, ordenação e busca local
- 📊 **Progresso de leitura** por capítulo ou página, com barra de progresso
- ⏭️ **Continuar lendo** na tela inicial, com atalho de "+1 capítulo"
- 🎨 **Tema claro / escuro / sistema**, persistido entre sessões
- ☁️ **Sincronização** via Cloud Firestore — a mesma estante no PC e no celular
- 📱 **PWA**: dá para instalar na tela inicial do celular

---

## ⚡ Desempenho da busca

A busca era o ponto mais lento do app (8–15s por consulta). O que mudou:

| Problema | Correção |
| --- | --- |
| MangaDex fazia ~25 requisições sequenciais por busca (1 por capa, 1 por detalhe, 1 por autor) | Uma única requisição com `includes[]` — capa, autores e tags já vêm em `relationships` |
| Um único limitador de taxa estático era compartilhado por todas as APIs, atrasando buscas paralelas | Limitador por host; só a Jikan tem intervalo mínimo |
| Cada requisição abria uma conexão TCP/TLS nova | `http.Client` único e reaproveitado |
| Uma API fora do ar segurava a busca inteira até o timeout | Disjuntor por fonte, com espera crescente (3 → 10 → 30 min) |
| A tela só aparecia quando a fonte mais lenta terminava | `Stream<SearchSnapshot>`: cada fonte que responde já pinta a lista |
| Busca repetida refazia tudo | Cache em memória com TTL de 10 min |
| Payloads inteiros eram baixados | `fields` no Google Books e no Open Library corta o tamanho pela metade |
| Home fazia uma leitura completa do Firestore só para as estatísticas | As estatísticas saem do mesmo stream da estante |
| Ordenação colocava livros na frente, sempre | Ranking por relevância (título exato > prefixo > tokens), com desempate por popularidade |

**Resultado medido:** primeiro resultado em **0,25–0,7s**, busca completa em
**0,8–2,1s**, repetição em cache **~1ms**.

> ℹ️ No build **Web** a MangaDex não envia `Access-Control-Allow-Origin`, então o
> navegador bloqueia a chamada. Por isso a **Kitsu** foi adicionada: ela cobre
> mangá/manhwa/manhua/light novel, responde CORS e mantém a busca de quadrinhos
> funcionando no site. Nos builds nativos as duas fontes são usadas.

---

## 🏗️ Estrutura

```
onde_parei/lib/
├── main.dart                       # Providers, tema e roteamento
├── models/
│   ├── api_models.dart             # Jikan, MangaDex, Kitsu, Google Books, Open Library
│   └── item_model.dart             # Item da estante + progresso
├── screens/
│   ├── auth/                       # Login, cadastro e moldura comum
│   ├── home/                       # Shell com abas + tela inicial
│   ├── items/                      # Formulário compartilhado (criar/editar) e lista
│   ├── search/                     # Busca progressiva
│   └── settings/                   # Perfil, tema e manutenção
├── services/
│   ├── api_service.dart            # Busca unificada, cache, rate limit, disjuntor
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── search_history_service.dart
├── theme/
│   ├── app_theme.dart              # Paleta "Biblioteca Clássica" + tokens M3
│   └── theme_controller.dart       # Preferência de tema persistida
└── widgets/                        # Capas, selos, skeletons e estados vazios
```

---

## 📦 Rodando localmente

```bash
cd onde_parei
flutter pub get
flutter run -d chrome
```

Testes e análise estática:

```bash
cd onde_parei && flutter test && flutter analyze
```

### Configuração do Firebase

`lib/firebase_options.dart` e `lib/config/api_keys.dart` estão no `.gitignore`.
Para recriá-los:

```bash
flutter pub global activate flutterfire_cli
cd onde_parei && flutterfire configure
```

A chave do Google Books pode ser passada sem editar arquivos:

```bash
flutter run --dart-define=GOOGLE_BOOKS_API_KEY=SuaChaveAqui
```

---

## 🚀 Deploy

```bash
cd onde_parei && flutter build web --release && firebase deploy
```

Isso publica o site, as regras do Firestore e os índices. O `firebase.json`
define cache longo para assets e `no-cache` para o HTML e o bundle, de modo que
uma nova versão chega no celular sem precisar limpar o cache.

---

## 🛠️ Stack

**Flutter** · **Dart** · **Provider** · **Material 3**
**Firebase Auth** · **Cloud Firestore** · **Firebase Hosting**
**MangaDex** · **Kitsu** · **Jikan (MyAnimeList)** · **Google Books** · **Open Library**

---

## 👨‍💻 Autor

**Vinícius Gabriel**
- GitHub: [@vinicius-gabriel297](https://github.com/vinicius-gabriel297)
- LinkedIn: https://www.linkedin.com/in/vinicius-silva-59a420213/

---

*Feito em Flutter para quem sempre esquece em que capítulo parou.*
