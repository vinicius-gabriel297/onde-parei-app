import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../models/user_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  bool _isDarkMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  UserSettings? _currentSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final settingsService = Provider.of<SettingsService>(context, listen: false);

      final user = authService.currentUser;
      if (user != null) {
        final settings = await settingsService.loadSettings(user.uid);
        setState(() {
          _currentSettings = settings;
          _displayNameController.text = settings.displayName;
          _isDarkMode = settings.isDarkMode;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar configurações: $e';
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final settingsService = Provider.of<SettingsService>(context, listen: false);

      final user = authService.currentUser;
      if (user != null) {
        final updatedSettings = _currentSettings!.copyWith(
          displayName: _displayNameController.text.trim(),
          isDarkMode: _isDarkMode,
        );

        await settingsService.saveSettings(updatedSettings);

        setState(() {
          _currentSettings = updatedSettings;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Tema será atualizado automaticamente pelo ChangeNotifier
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Seção de perfil
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue,
                            radius: 30,
                            child: const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Perfil',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Configure seu perfil e preferências',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Nome de exibição
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nome de Exibição',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          hintText: 'Como você quer ser chamado?',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nome de exibição é obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Este nome aparecerá na tela inicial ao invés do email',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Configurações de aparência
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aparência',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Tema Escuro'),
                        subtitle: const Text('Alterne entre tema claro e escuro'),
                        value: _isDarkMode,
                        onChanged: (value) {
                          setState(() {
                            _isDarkMode = value;
                          });
                        },
                        secondary: Icon(
                          _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sobre o app
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sobre',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('Versão'),
                        subtitle: const Text('1.0.0'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.code),
                        title: const Text('Desenvolvido com'),
                        subtitle: const Text('Flutter & Firebase'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Mensagem de erro
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 16),

              // Botão salvar
              ElevatedButton(
                onPressed: _isLoading ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Salvar Configurações',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
