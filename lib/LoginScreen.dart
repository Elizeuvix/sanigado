import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'Home.dart';
import 'Configurar.dart';
import 'Cadastrar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  final _formKey = GlobalKey<FormState>();
  String urlSanigado = "http://192.168.3.196/sanigado/api";
  String userSanigado = "";
  String senhaSanigado = "";
  //String urlSanigado = "http://10.0.2.2/sanigado/api"; //URL padrão para testes localhost

  // Cores do tema JBS
  final Color primaryColor = const Color(0xFF0054A6);
  final Color accentColor = const Color(0xFF0078D7);
  final Color backgroundColor = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
    _loadServerUrl();
    _loadSavedUser(); // Carrega os dados do usuário salvo
  }

  Future<void> _checkInitialAuth() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final dir = await getApplicationDocumentsDirectory();
    final userFile = File('${dir.path}/usuario-sanigado.json');
    if (connectivityResult == ConnectivityResult.none) {
      if (await userFile.exists()) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Home()),
          );
        }
      }
    }
  }

  Future<void> _loadServerUrl() async {

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/url-sanigado.json');
      if (await file.exists()) {
        final conteudo = await file.readAsString();
        print("URL SANIGADO: " +  conteudo);
        if (conteudo.trim().isNotEmpty) {
          setState(() {
            urlSanigado = conteudo.trim();
          });
        }
      }

    } catch (e) {
      print("Erro ao carregar URL: $e");
    }
  }

  Future<void> _autenticar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final dir = await getApplicationDocumentsDirectory();
      final userFile = File('${dir.path}/usuario-sanigado.json');

      // Modo offline - verifica se existe usuário salvo
      if (connectivityResult == ConnectivityResult.none) {
        if (await userFile.exists()) {
          final userData = jsonDecode(await userFile.readAsString());
          if (userData['login'] == _loginController.text) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Home()),
            );
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usuário não encontrado localmente'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você precisa estar online para fazer o primeiro login'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Modo online - autenticação normal
      final authResult = await autenticarUsuario(
        _loginController.text,
        _senhaController.text,
        urlSanigado,
      );

      if (!mounted) return;

      if (authResult['success'] == true) {
        if (authResult['data'] != null && authResult['data'] is Map) {
          await salvarUsuarioLocal(authResult['data']);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login realizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Home()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authResult['message'] ?? 'Falha no login'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro durante o login: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: accentColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          labelStyle: TextStyle(color: primaryColor),
        ),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    Image.asset(
                      'lib/assets/icons/icon.png',
                      height: 120,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Bem-vindo',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Faça login para continuar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Usuário',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira seu usuário';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _senhaController,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText ? Icons.visibility : Icons.visibility_off,
                            color: primaryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureText,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira sua senha';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: _autenticar,
                      child: const Text('ENTRAR'),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Cadastrar()),
                        );
                      },
                      child: Text(
                        'Novo Usuário',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Configurar()),
                        );
                      },
                      child: Text(
                        'Configurar Servidor',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    /* Botão para acessar a tela de testes

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Testes()),
                        );
                      },
                      child: Text(
                        'Tela de Testes',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                    */
                    // Fim - Botão para acessar a tela de testes
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _loadSavedUser() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final userFile = File('${dir.path}/usuario-sanigado.json');

      if (await userFile.exists()) {
        final userData = jsonDecode(await userFile.readAsString());
        setState(() {
          _loginController.text = userData['login'] ?? '';
          _senhaController.text = userData['senha'] ?? '';
        });
      }
    } catch (e) {
      print("Erro ao carregar usuário salvo: $e");
    }
  }
}

Future<Map<String, dynamic>> autenticarUsuario(
    String login,
    String senha,
    String urlSanigado,
    ) async {
  try {
    final uri = Uri.parse('$urlSanigado/login.php');
    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"login": login, "senha": senha}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Erro no servidor (${response.statusCode})',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Erro de conexão: ${e.toString()}',
    };
  }
}

Future<void> salvarUsuarioLocal(Map<String, dynamic> dadosUsuario) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/usuario-sanigado.json');
    await file.writeAsString(jsonEncode(dadosUsuario));
  } catch (e) {
    throw Exception('Falha ao salvar dados do usuário localmente');
  }
}
