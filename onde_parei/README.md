# Onde Parei? 📚

Aplicativo Flutter para rastrear mangás e livros favoritos, permitindo salvar onde você parou a leitura.

## Funcionalidades

- ✅ Autenticação de usuário (cadastro/login)
- ✅ Busca de mangás e livros através de APIs gratuitas
- ✅ Adicionar itens manualmente
- ✅ Rastrear progresso de leitura (capítulo atual/página atual)
- ✅ Sistema de status (Lendo, Lido, Pretendo Ler)
- ✅ Sistema de avaliação (estrelas)
- ✅ Banco de dados Firebase para armazenamento
- ✅ Interface responsiva e intuitiva

## APIs Utilizadas

- **Jikan API** (https://jikan.moe/) - Para busca de mangás
- **Open Library Search API** (https://openlibrary.org/dev/docs/api/search) - Para busca de livros
- **Firebase** - Para autenticação e banco de dados

## Configuração do Projeto

### 1. Pré-requisitos

- Flutter SDK instalado
- Conta no Firebase
- Android Studio ou VS Code

### 2. Configuração do Firebase

#### Método Automático (Recomendado):

```bash
# 1. Instalar Firebase CLI
npm install -g firebase-tools

# 2. Fazer login no Firebase
firebase login

# 3. Configurar o projeto Flutter com Firebase
flutter pub global activate flutterfire_cli
flutter pub global run flutterfire_cli configure --project=onde-parei-app
```

#### Método Manual:

1. **Criar projeto no Firebase:**
   - Vá para [Firebase Console](https://console.firebase.google.com/)
   - Clique em "Criar projeto" (ex: "onde-parei-app")
   - Aguarde a criação

2. **Ativar serviços:**
   - No menu lateral, vá em "Authentication"
   - Clique em "Começar"
   - Vá na aba "Método de login"
   - Ative "Email/Senha"
   - Clique em "Salvar"

   - No menu lateral, vá em "Firestore Database"
   - Clique em "Criar banco de dados"
   - Selecione "Modo de produção"
   - Clique em "Próximo" e depois "Concluir"

3. **Adicionar app Android:**
   - No projeto Firebase, clique em "Adicionar app" (ícone Android)
   - Nome do pacote: `com.example.onde_parei`
   - Clique em "Registrar app"
   - Baixe o arquivo `google-services.json`
   - Mova para: `onde_parei/android/app/google-services.json`

4. **Adicionar app iOS:**
   - No projeto Firebase, clique em "Adicionar app" (ícone iOS)
   - Bundle ID: `com.example.ondeParei`
   - Clique em "Registrar app"
   - Baixe o arquivo `GoogleService-Info.plist`
   - Mova para: `onde_parei/ios/Runner/GoogleService-Info.plist`

5. **Configurar credenciais:**
   - No Firebase Console, vá em "Configurações do projeto" (engrenagem)
   - Vá na aba "Seus apps"
   - Clique no ícone do Android/iOS
   - Copie as credenciais (apiKey, appId, etc.)
   - Cole no arquivo `lib/firebase_options.dart`

### 3. Configuração das dependências

```bash
cd onde_parei
flutter pub get
```

### 4. Executar o aplicativo

```bash
flutter run
```

#### ⚠️ Se der erro de configuração do Firebase:

O arquivo `lib/firebase_options.dart` já está configurado com valores de exemplo. Você precisa substituí-los pelas suas credenciais reais do Firebase Console.

**Procure por estas linhas e substitua:**
```dart
apiKey: 'YOUR_API_KEY', // ← Substitua pela sua chave
appId: 'YOUR_APP_ID',   // ← Substitua pelo seu ID
// ... etc
```

### 5. Executar o aplicativo

```bash
flutter run
```

## Estrutura do Projeto

```
lib/
├── models/
│   └── reading_item.dart          # Modelo de dados para mangás/livros
├── services/
│   ├── auth_service.dart          # Serviço de autenticação
│   ├── database_service.dart      # Serviço do banco de dados
│   └── api_service.dart           # Serviço das APIs externas
├── providers/
│   ├── auth_provider.dart         # Provider de autenticação
│   └── reading_provider.dart      # Provider de leitura
├── screens/
│   ├── login_screen.dart          # Tela de login/cadastro
│   ├── home_screen.dart           # Tela principal
│   ├── search_screen.dart         # Tela de busca
│   ├── add_item_screen.dart       # Tela de adicionar/editar
│   └── item_detail_screen.dart    # Tela de detalhes do item
└── main.dart                      # Arquivo principal
```

## Funcionalidades Detalhadas

### Tela de Login/Cadastro
- Login com email e senha
- Cadastro de novos usuários
- Recuperação de senha
- Validação de formulários

### Tela Principal
- Lista de itens organizados por status
- Filtros por status (Todos, Lendo, Lido, Pretendo Ler)
- Busca rápida
- Adicionar novos itens

### Tela de Busca
- Busca de mangás através da Jikan API
- Busca de livros através da Open Library API
- Alternância entre mangá e livro
- Adicionar itens encontrados à biblioteca pessoal

### Tela de Detalhes
- Visualização completa do item
- Atualização rápida de progresso
- Edição de informações
- Exclusão de itens
- Visualização de progresso com barra

### Tela de Adicionar/Editar
- Formulário completo para adicionar itens
- Suporte para itens de API ou manuais
- Seleção de tipo (mangá/livro)
- Definição de status
- Sistema de avaliação
- Campos opcionais (autor, descrição, etc.)

## Tecnologias Utilizadas

- **Flutter** - Framework para desenvolvimento mobile
- **Dart** - Linguagem de programação
- **Firebase Auth** - Autenticação de usuários
- **Cloud Firestore** - Banco de dados NoSQL
- **Provider** - Gerenciamento de estado
- **HTTP** - Requisições para APIs externas
- **Cached Network Image** - Cache de imagens
- **Flutter Rating Bar** - Sistema de avaliação

## Próximas Funcionalidades

- [ ] Sincronização offline
- [ ] Notificações push
- [ ] Backup e exportação de dados
- [ ] Estatísticas de leitura
- [ ] Compartilhamento de progresso
- [ ] Modo escuro
- [ ] Suporte a múltiplos idiomas

## Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

## Suporte

Para suporte, abra uma issue no GitHub ou entre em contato através do email: suporte@ondeparei.com
