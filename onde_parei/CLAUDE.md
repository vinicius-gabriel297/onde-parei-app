# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

O código, os comentários e a UI estão em **português do Brasil** — mantenha esse idioma ao escrever comentários, mensagens de erro e textos de tela.

## Layout

O repositório é um wrapper: o app Flutter fica em `onde_parei/`. Praticamente todo comando precisa rodar dentro dessa pasta.

## Comandos

```bash
cd onde_parei && flutter pub get
```

```bash
cd onde_parei && flutter run -d chrome
```

Análise estática e testes (só há dois arquivos de teste, ambos unitários/widget — não há integração):

```bash
cd onde_parei && flutter analyze && flutter test
```

Um único arquivo ou um único caso:

```bash
cd onde_parei && flutter test test/widget_test.dart --plain-name "extrai capa e autores"
```

Build web + deploy (publica hosting, regras e índices do Firestore juntos):

```bash
cd onde_parei && flutter build web --release && firebase deploy
```

Ícones do app, depois de trocar `assets/icon/`:

```bash
cd onde_parei && dart run flutter_launcher_icons
```

## Configuração local obrigatória

`lib/firebase_options.dart` e `lib/config/api_keys.dart` estão no `.gitignore` e **não** vêm no clone. Sem eles o app não compila. Para recriar:

```bash
flutter pub global activate flutterfire_cli && cd onde_parei && flutterfire configure
```

Projeto Firebase: `onde-parei-ea32c`. A chave do Google Books também pode vir por `--dart-define=GOOGLE_BOOKS_API_KEY=...`, que é o que `ApiKeys.googleBooks` lê via `String.fromEnvironment`.

## Arquitetura

Camadas: `screens/` (UI) → `services/` (dados) → `models/`. Não há repositório nem camada de domínio intermediária; as telas falam direto com os serviços.

**Injeção e estado** — `main.dart` monta um `MultiProvider` com `AuthService`, `FirestoreService`, `SearchHistoryService` (todos `Provider`, sem estado observável) e `ThemeController` (o único `ChangeNotifier`). Estado de tela é `setState` local. `AuthWrapper` escuta `authStateChanges` e decide entre `LoginScreen` e `HomeShell`; `HomeShell` é um `IndexedStack` de 4 abas (home, estante, busca, ajustes).

**Busca multi-fonte (`services/api_service.dart`)** — é o núcleo do app e concentra a complexidade. Tudo é `static`. `searchStream()` dispara 5–6 fontes em paralelo (Catálogo Firestore, Google Books, Open Library, MangaDex, Kitsu, Jikan/MyAnimeList, filtradas por `SearchScope`) e emite um `SearchSnapshot` a cada fonte que termina, em vez de esperar a mais lenta. Quatro mecanismos protegem esse caminho, e mudanças aqui devem preservá-los:

- `_MemoryCache` — LRU estático, TTL de 10 min, chaveado pela URI completa.
- `_RateLimiter` — intervalo mínimo **por host** (só a Jikan usa, 400 ms). Um limitador global fazia buscas paralelas se atrasarem mutuamente.
- `_Breaker` — disjuntor por fonte: 2 falhas abrem o circuito por 3 → 10 → 30 min. É o que impede a MangaDex (bloqueada por CORS no Web) de custar um timeout a cada busca. `ApiService.reset()` reabre tudo e limpa o cache — é o "tentar novamente" da UI.
- `_client` — um único `http.Client` reaproveitado; nada deve usar `http.get` avulso.

Depois vêm dedupe (`_mergeInto`, por `SearchResult.dedupeKey`, com prioridade de fonte em `_sourceRank` e preferência por quem tem capa) e `rank()` — pontuação por casamento de título (exato > prefixo > tokens, com distância de edição 1), penalidades para volumes/derivados, e popularidade só como desempate. Ordenar por tipo, aqui, é regressão conhecida.

Cada API tem seu modelo em `models/api_models.dart` e um `SearchResult.fromX()`. A MangaDex traz capa, autores e tags via `includes[]` em **uma** requisição — não volte a buscar `relationships` uma a uma.

**Firestore (`services/firestore_service.dart`)** — duas coleções:
- `items`: estante por usuário, filtrada por `userId`; os três índices compostos em `firestore.indexes.json` correspondem às queries `getUserItems*`. Nova combinação de `where` + `orderBy` exige índice novo.
- `book_catalog`: cache **compartilhado** entre todos os usuários dos títulos já pesquisados; é a primeira fonte a responder na busca. Escrita é best-effort e silenciosa (`upsertBookToCatalog` nunca pode impedir o usuário de salvar o item).

Estatísticas da home saem de `statsFrom(items)` sobre a lista já carregada do stream — não faça uma segunda leitura da coleção só para contar.

**Modelo (`models/item_model.dart`)** — `ItemType` e `ReadingStatus` são persistidos no Firestore **pelo índice do enum**: só acrescente valores no fim, nunca reordene. `countsChapters` define se a UI conta capítulos (mangá/manhwa/manhua) ou páginas (livro). Progresso é armazenado como `String` para permitir campo vazio.

**Tema e UI** — `theme/app_theme.dart` define a paleta "Biblioteca Clássica" e é a **única** fonte de cores; não use `Color(0x...)` literal nas telas. `ThemeController` persiste a preferência em `SharedPreferences` (padrão: escuro). Componentes reutilizáveis (`TypeBadge`, `StatusPill`, `ReadingProgressBar`, `CoverArt`, `EmptyState`, snackbars) ficam em `widgets/ui_kit.dart` — prefira estendê-los a criar variantes locais.

**Imagens** — sempre `AdaptiveNetworkImage`, não `Image.network`: ele força https (mixed content no Web), tem fallback por proxy quando a origem bloqueia hotlink e decodifica no tamanho de exibição. `ItemModel.normalizeImageUrl` faz a mesma normalização na leitura, e `migrateUserImageUrlsToHttps` conserta documentos antigos.

## Web

O build web é o alvo principal (o app é um PWA em https://onde-parei-ea32c.web.app). Duas consequências recorrentes: a MangaDex não responde CORS no navegador — a Kitsu existe para cobrir mangá/manhwa/manhua nesse ambiente; e o `firebase.json` define `no-cache` para HTML/bundle e cache longo para assets, para que uma versão nova chegue sem limpar cache.
