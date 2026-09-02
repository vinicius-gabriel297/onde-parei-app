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

`ApiService.lookupTotalUnits` é o caminho pontual para descobrir o total de páginas/capítulos de um item salvo sem esse número, disparado só pelo botão do formulário. Para livro, o **Open Library vem antes do Google Books**: o catálogo dele é de edições físicas e `number_of_pages_median` já é a mediana entre elas, enquanto o Google mistura ebook (paginação maior) e impresso na mesma resposta. Quem decide o número é `pageCountFromEditions`, que é pura e testada: descarta título derivado (box, coleção, resumo), descarta menos de 40 páginas e devolve a **mediana** das edições que casam com o título — pegar a primeira trazia o ebook ou o box. A função nunca escreve sozinha; o valor vai para o campo e o usuário confirma.

Cada API tem seu modelo em `models/api_models.dart` e um `SearchResult.fromX()`. A MangaDex traz capa, autores e tags via `includes[]` em **uma** requisição — não volte a buscar `relationships` uma a uma.

**Firestore (`services/firestore_service.dart`)** — duas coleções:
- `items`: estante por usuário, filtrada por `userId`; os três índices compostos em `firestore.indexes.json` correspondem às queries `getUserItems*`. Nova combinação de `where` + `orderBy` exige índice novo.
- `book_catalog`: cache **compartilhado** entre todos os usuários dos títulos já pesquisados; é a primeira fonte a responder na busca. Escrita é best-effort e silenciosa (`upsertBookToCatalog` nunca pode impedir o usuário de salvar o item).

Estatísticas da home saem de `statsFrom(items)` sobre a lista já carregada do stream — não faça uma segunda leitura da coleção só para contar.

**Modelo (`models/item_model.dart`)** — `ItemType` e `ReadingStatus` são persistidos no Firestore **pelo índice do enum**: só acrescente valores no fim, nunca reordene (`test/reading_status_test.dart` trava os índices atuais). Por isso a ordem que a UI mostra vive em `ReadingStatusX.displayOrder`, e é ela que o seletor do formulário e os chips da estante percorrem — nunca `ReadingStatus.values`. `countsChapters` define se a UI conta capítulos (mangá/manhwa/manhua) ou páginas (livro). Progresso é armazenado como `String` para permitir campo vazio.

`review` é o texto final da obra, escrito quando a leitura encerra (`read` ou `dropped`). É `String` vazia em vez de `null`, como `currentChapter`, para poder ser limpo sem sentinela no `copyWith`. O formulário esconde a seção quando o status volta a ser em andamento, mas **não** apaga o texto. O review é privado: não vai para o `book_catalog`, só sai do app como imagem.

`startedAt` e `finishedAt` são as datas da **leitura** (não do documento, que é `createdAt`/`updatedAt`). Quem as mantém coerentes é `ItemModel.datesFor`, que depende só do status de destino — "lendo"/"em pausa" preenchem o início e limpam o fim, "lido"/"abandonei" carimbam o fim, "quero ler" zera as duas — e nunca sobrescreve data já preenchida, inclusive a escolhida à mão nos campos do formulário. Item salvo antes desta versão fica com as duas nulas: nada as deduz de `updatedAt`, e é por isso que a retrospectiva ignora obra lida sem data em vez de inventar um ano para ela.

**Retrospectiva (`services/recap_service.dart`)** — `ReadingRecap.forYear(items, ano)` é puro e roda sobre a lista que a tela já tem do stream: contagem por mês, livros x quadrinhos, páginas/capítulos, gêneros, obra favorita e média de dias. Trocar de ano recalcula em memória — não faça consulta nova por ano nem crie índice para isso. A tela vive em `screens/recap/`, entra pelo card no Perfil, e o card de compartilhamento (`widgets/recap_card.dart`) segue as mesmas regras do de review: medidas fixas, capa resolvida antes da captura, rodapé compartilhado em `ShareCardFooter`.

O par `source` + `externalId` guarda de onde a obra veio (`jikan` + `mal-2`, por exemplo) e é preenchido **só na criação**, a partir do `SearchResult`; item digitado à mão fica com os dois nulos. Como o `book_catalog` é apenas um cache, um resultado que volta de lá chega com `source: catalog` — quem carrega a fonte verdadeira é `SearchResult.originSource`, e é `effectiveSource` que deve ser lido, nunca `source` direto.

**Tema e UI** — `theme/app_theme.dart` define a paleta "Biblioteca Clássica" e é a **única** fonte de cores; não use `Color(0x...)` literal nas telas. `ThemeController` persiste a preferência em `SharedPreferences` (padrão: escuro). Componentes reutilizáveis (`TypeBadge`, `StatusPill`, `ReadingProgressBar`, `CoverArt`, `EmptyState`, snackbars) ficam em `widgets/ui_kit.dart` — prefira estendê-los a criar variantes locais.

**Card de compartilhamento** — `widgets/review_card.dart` desenha um card de tamanho **fixo** (540x675 lógicos); `services/share_service.dart` o captura de um `RepaintBoundary` com `pixelRatio: 2`, o que dá 1080x1350 (4:5 de feed). Mexer nas medidas do card muda o PNG — `test/share_service_test.dart` trava o resultado. `ShareReviewScreen` resolve a capa **antes** de liberar a captura, percorrendo `AdaptiveNetworkImage.candidateUrls`: no Web só entra no PNG imagem servida com CORS, e é o proxy dessa lista que garante isso. A entrega é `share_plus` e, quando o navegador recusa arquivo (Web desktop), `downloadBytesFile` — o mesmo par tentativa/queda da exportação.

**Imagens** — sempre `AdaptiveNetworkImage`, não `Image.network`: ele força https (mixed content no Web), tem fallback por proxy quando a origem bloqueia hotlink e decodifica no tamanho de exibição. `ItemModel.normalizeImageUrl` faz a mesma normalização na leitura, e `migrateUserImageUrlsToHttps` conserta documentos antigos.

## Web

O build web é o alvo principal (o app é um PWA em https://onde-parei-ea32c.web.app). Duas consequências recorrentes: a MangaDex não responde CORS no navegador — a Kitsu existe para cobrir mangá/manhwa/manhua nesse ambiente; e o `firebase.json` define `no-cache` para HTML/bundle e cache longo para assets, para que uma versão nova chegue sem limpar cache.
