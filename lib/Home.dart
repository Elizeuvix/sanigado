import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show InternetAddress, SocketException;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'LoginScreen.dart';
import 'Mortalidade.dart';
import 'Configurar.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String nomeUsuario = "Usuário";
  int _registrosPendentes = 0;
  bool _temInternet = true;
  bool _sincronizando = false;
  String urlSanigado = '';

  final Color primaryColor = const Color(0xFF0054A6);
  final Color accentColor = const Color(0xFF0078D7);
  final Color backgroundColor = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
    _verificarConexao();
    _configurarListenerConexao();
    _loadServerUrl().then((_) => _contarRegistrosPendentes());
  }

  Future<void> _loadServerUrl() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/url-sanigado.json');
      if (await file.exists()) {
        final conteudo = await file.readAsString();
        setState(() => urlSanigado = conteudo.trim());
      }
    } catch (e) {
      print("Erro ao carregar URL: $e");
    }
  }

  Future<void> _carregarUsuario() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/usuario-sanigado.json');
      if (await file.exists()) {
        final dados = jsonDecode(await file.readAsString());
        setState(() => nomeUsuario = dados['nome'] ?? "Usuário");
      }
    } catch (e) {
      print("Erro ao carregar usuário: $e");
    }
  }

  Future<void> _verificarConexao() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      setState(() => _temInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } on SocketException catch (_) {
      setState(() => _temInternet = false);
    }
  }

  void _configurarListenerConexao() {
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() => _temInternet = result != ConnectivityResult.none);
    });
  }

  Future<void> _contarRegistrosPendentes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mortalidades-sanigado.json');

      if (!await file.exists()) {
        setState(() => _registrosPendentes = 0);
        return;
      }

      final conteudo = await file.readAsString();
      if (conteudo.trim().isEmpty) {
        await file.writeAsString('[]');
        setState(() => _registrosPendentes = 0);
        return;
      }

      final registros = jsonDecode(conteudo) as List<dynamic>;
      setState(() => _registrosPendentes = registros.length);
    } catch (e) {
      print("Erro ao contar registros: $e");
      await _corrigirArquivoCorrompido();
      setState(() => _registrosPendentes = 0);
    }
  }

  Future<void> _corrigirArquivoCorrompido() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/mortalidades-sanigado.json');
    await file.writeAsString('[]', flush: true);
  }

  Future<void> _sincronizarRegistros() async {
    if (urlSanigado.isEmpty) {
      _mostrarSnackBar('URL do backend não configurada', Colors.red);
      return;
    }

    setState(() => _sincronizando = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mortalidades-sanigado.json');

      if (!await file.exists() || _registrosPendentes == 0) {
        _mostrarSnackBar('Nenhum registro pendente para sincronizar', Colors.blue);
        return;
      }

      final conteudo = await file.readAsString();
      final registros = await _validarERecuperarRegistros(conteudo, file);
      if (registros.isEmpty) return;

      final registrosParaManter = <dynamic>[];
      int registrosEnviados = 0;

      for (var registro in registros) {
        try {
          await _enviarRegistro(registro);
          registrosEnviados++;
        } catch (e) {
          registrosParaManter.add(registro);
          _mostrarErroRegistro(registro['brinco'], e);
        }
      }

      await _atualizarArquivoLocal(file, registrosParaManter);
      _mostrarResultadoSincronizacao(registrosEnviados);
      await _contarRegistrosPendentes();
    } catch (e) {
      _mostrarSnackBar('Erro na sincronização: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _sincronizando = false);
    }
  }

  Future<List<dynamic>> _validarERecuperarRegistros(String conteudo, File file) async {
    try {
      return jsonDecode(conteudo) as List<dynamic>;
    } catch (e) {
      print('JSON corrompido: $e');
      await _corrigirArquivoCorrompido();
      return [];
    }
  }

  Future<void> _enviarRegistro(dynamic registro) async {
    final dadosParaEnvio = {
      'tipo_morte': registro['grupo_causa'],
      'subtipo_morte': registro['causa_morte'],
      'descricao': registro['descricao'],
      'data_hora': registro['data'],
      'laudo': registro['laudo'],
      'retiro': registro['retiro'],
      'local': registro['localidade'],
      'notificante': registro['notificante'],
      'brinco': registro['brinco'],
      'liberado': 0,
      'foto': registro['foto'],
    };

    final response = await http.post(
      Uri.parse('$urlSanigado/registrar_mortalidade.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dadosParaEnvio),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} - ${response.body}');
    }

    final resposta = jsonDecode(response.body);
    if (!resposta['success']) {
      throw Exception(resposta['message']);
    }
  }

  Future<void> _atualizarArquivoLocal(File file, List<dynamic> registros) async {
    await file.writeAsString(jsonEncode(registros), flush: true);
  }

  void _mostrarResultadoSincronizacao(int registrosEnviados) {
    if (registrosEnviados > 0) {
      _mostrarSnackBar('$registrosEnviados registros sincronizados!', Colors.green);
    }
  }

  void _mostrarErroRegistro(dynamic brinco, dynamic erro) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro no registro $brinco: ${_simplificarMensagemErro(erro)}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _simplificarMensagemErro(dynamic erro) {
    if (erro is SocketException) return 'Sem conexão com o servidor';
    if (erro is TimeoutException) return 'Tempo limite excedido';
    return erro.toString().replaceAll('Exception: ', '');
  }

  void _mostrarSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _sairDoApp() => SystemNavigator.pop();

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
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('SANIGADO'),
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          actions: [
            if (_sincronizando)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Marca d'água de fundo
              Opacity(
                opacity: 0.2,
                child: Image.asset(
                  'lib/assets/images/marcadagua.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),

              // Conteúdo principal
              SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Image.asset('lib/assets/icons/icon.png', height: 120),
                      const SizedBox(height: 30),
                      Text(
                        'Olá, $nomeUsuario',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (urlSanigado.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Backend não configurado',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 40),
                      _buildMenuButton(
                        icon: Icons.switch_account,
                        text: "Trocar Usuário",
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        icon: Icons.assignment,
                        text: "Registrar Morte",
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Mortalidade()),
                        ).then((_) => _contarRegistrosPendentes()),
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        icon: Icons.sync,
                        text: _sincronizando
                            ? "Sincronizando..."
                            : "Sincronizar ($_registrosPendentes)",
                        onPressed: (!_temInternet || _registrosPendentes < 1 || _sincronizando || urlSanigado.isEmpty)
                            ? null
                            : _sincronizarRegistros,
                      ),
                      const Divider(
                        height: 20,
                        thickness: 1,
                        color: Colors.grey,
                      ),
                      _buildMenuButton(
                        icon: Icons.exit_to_app,
                        text: "Sair do Aplicativo",
                        onPressed: _sairDoApp,
                        isExit: true,
                      ),
                      const SizedBox(height: 30),
                      _buildMenuButton(
                        icon: Icons.settings,
                        text: "Configurar URL",
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Configurar()),
                        ).then((_) => _loadServerUrl().then((_) => _contarRegistrosPendentes())),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String text,
    required VoidCallback? onPressed,
    bool isExit = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(text, style: const TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isExit
            ? Colors.redAccent
            : (onPressed == null ? Colors.grey : primaryColor),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    );
  }
}