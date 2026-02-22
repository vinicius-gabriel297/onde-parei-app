# 📚 Onde Parei?

**"Onde Parei?"** é um aplicativo Flutter moderno para gerenciar sua leitura de **mangás e livros**. Construído com Firebase, oferece uma experiência completa de tracking de leitura com integração com APIs externas para descobrir novos títulos.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

## 🚀 Funcionalidades

### ✨ Principais Features
- 🔐 **Autenticação Seguro**: Login e cadastro com Firebase Auth
- 📖 **Biblioteca Pessoal**: Organize seus mangás e livros favoritados
- 🔍 **Busca Inteligente**: Integração com Jikan API (mangás) e Google Books API
- 📊 **Dashboard Estatístico**: Acompanhe seus progressos de leitura
- 🎨 **Interface Moderna**: Material Design 3 com dark/light mode
- ☁️ **Sincronização na Nuvem**: Dados salvos no Firebase Firestore
- 📱 **Multiplataforma**: Android, iOS, Web, Windows, macOS e Linux

### 📱 Screenshots


## 🛠️ Tecnologias Utilizadas

### Frontend
- **Flutter** - Framework principal
- **Dart** - Linguagem de programação
- **Provider** - Gerenciamento de estado
- **Material Design 3** - UI moderna

### Backend & Banco
- **Firebase Authentication** - Autenticação de usuários
- **Cloud Firestore** - Banco de dados NoSQL
- **SharedPreferences** - Configurações locais

### APIs Integradas
- **Jikan API** - Dados de mangás/animes
- **Google Books API** - Catálogo de livros

### Pacotes Flutter
```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.5.0

  # HTTP e APIs
  http: ^1.2.2

  # UI e UX
  cached_network_image: ^3.4.1
  flutter_rating_bar: ^4.0.1
  flutter_typeahead: ^5.1.2

  # Gerenciamento de Estado
  provider: ^6.1.2

  # Utilitários
  shared_preferences: ^2.2.3
  google_fonts: ^6.2.1
```

## 📦 Instalação

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (versão 3.8.1 ou superior)
- [Dart SDK](https://dart.dev/get-dart) (incluído com Flutter)
- [Git](https://git-scm.com/)
- Conta no [Firebase](https://console.firebase.google.com/)

### Passos de Instalação

1. **Clone o repositório:**
```bash
git clone https://github.com/SEU_USERNAME/onde-parei-app.git
cd onde-parei-app/onde_parei
```

2. **Instale as dependências:**
```bash
flutter pub get
```

3. **Configure o Firebase:**

   a. Crie um projeto no [Firebase Console](https://console.firebase.google.com/)

   b. Ative Authentication e Firestore Database

   c. Configure as regras de segurança do Firestore:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /items/{itemId} {
         allow read, write: if request.auth != null &&
           request.auth.uid == resource.data.userId;
       }

       match /items {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

   d. Configure o Firebase CLI:
   ```bash
   firebase login
   ```

   e. Deploy as regras:
   ```bash
   firebase deploy --only firestore:rules
   ```

4. **Execute o app:**
```bash
# Para Android/iOS conectados:
flutter run

# Para web:
flutter run -d chrome

# Para desktop:
flutter run -d windows
```

## 🚀 Como Usar

### Primeiro Uso
1. **Abra o app** → Tela de login aparecerá automaticamente
2. **Cadastre-se** com email e senha
3. **Configure preferências** nas configurações (opcional)

### Adicionando Itens
1. **Toque no botão "+"** (flutuante)
2. **Pesquise** por mangás ou livros
3. **Selecione o item** desejado
4. **Preencha os detalhes** (capítulo atual, avaliação, etc.)

### Navegação
- **🏠 Início**: Dashboard com estatísticas e itens recentes
- **📋 Meus Itens**: Lista completa da sua biblioteca
- **⚙️ Configurações**: Preferências do usuário

## 🏗️ Estrutura do Projeto

```
onde_parei/
├── lib/
│   ├── main.dart                 # Ponto de entrada da aplicação
│   ├── firebase_options.dart     # Configuração Firebase
│   ├── models/
│   │   ├── item_model.dart       # Modelo de dados dos itens
│   │   ├── user_settings.dart    # Configurações do usuário
│   │   └── api_models.dart       # Modelos das APIs externas
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── search/
│   │   │   └── search_screen.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   ├── services/
│   │   ├── auth_service.dart     # Autenticação Firebase
│   │   ├── firestore_service.dart # Banco de dados
│   │   ├── api_service.dart      # APIs externas
│   │   └── settings_service.dart # Configurações locais
│   └── widgets/                  # Widgets compartilhados
├── android/                      # Configurações Android
├── ios/                         # Configurações iOS
├── web/                         # Configurações Web
├── windows/                     # Configurações Windows
├── macos/                       # Configurações macOS
├── linux/                       # Configurações Linux
├── test/                        # Testes unitários
├── pubspec.yaml                 # Dependências Flutter
├── firebase.json                # Configuração Firebase
└── README.md                    # Este arquivo
```

## 🔧 Configuração de Desenvolvimento

### Debug
```bash
flutter run --debug
```

### Release Build
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

### Testes
```bash
flutter test
```

### Análise de Código
```bash
flutter analyze
```

## 🎯 Status do Projeto

- ✅ **Autenticação**: Firebase Auth implementado
- ✅ **Interface**: Todas as telas desenvolvidas
- ✅ **APIs**: Integração com Jikan e Google Books
- ✅ **Banco de Dados**: Firestore configurado
- ✅ **Estado**: Gerenciamento com Provider
- ✅ **Nuvem**: Deploy das regras necessário
- 🔄 **Funcionalidades**: Completas e testáveis

## 🤝 Contribuições

Contribuições são bem-vindas! 🎉

### Como contribuir:
1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

### Diretrizes:
- Siga a convenção de commits
- Mantenha o código limpo
- Adicione testes para novas funcionalidades
- Atualize a documentação quando necessário

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 👨‍💻 Autor

**Vinícius**
- GitHub: [@vinicius-gabriel297](https://github.com/vinicius-gabriel297)
- LinkedIn: [https://www.linkedin.com/in/vinicius-silva-59a420213/]
- E-mail: viniciuscarvalho.silva676@gmail.com

---

⭐ **Gostou do projeto? Dê um star no GitHub!**

📱 **Disponível para**: Android | iOS | Web | Windows | macOS | Linux

---

*Desenvolvido com ❤️ em Flutter para amantes de leitura*
