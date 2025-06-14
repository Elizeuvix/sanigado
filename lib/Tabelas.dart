import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class Tabelas extends StatefulWidget {
  const Tabelas({Key? key}) : super(key: key);

  @override
  _TabelasState createState() => _TabelasState();
}

class _TabelasState extends State<Tabelas> {
  bool _isLoading = false;
  String _statusMessage = '';
  String urlSanigado = "http://192.168.3.196/sanigado/api";

  // Cores do tema JBS
  final Color primaryColor = const Color(0xFF0054A6);
  final Color accentColor = const Color(0xFF0078D7);

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/url-sanigado.json');
      if (await file.exists()) {
        final conteudo = await file.readAsString();
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

  Future<void> _sincronizarTabelas() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Iniciando sincronização...';
    });

    try {
      await Future.wait([
        _sincronizarGruposCausas(),
        _sincronizarCausasMorte(),
        _sincronizarRetiros(),
      ]);

      setState(() {
        _statusMessage = 'Sincronização concluída com sucesso!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tabelas sincronizadas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro durante a sincronização: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sincronizarGruposCausas() async {
    setState(() {
      _statusMessage = 'Sincronizando Grupos de Causas...';
    });
    try {
      final response = await http.get(
        Uri.parse('$urlSanigado/tipos_morte.php'),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          final tipos = data.map<String>((item) => item['tipo_morte'].toString()).toList();

          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/grupo-causas-sanigado.json');
          await file.writeAsString(jsonEncode(tipos));

          return;
        }
        throw Exception('Formato de dados inválido para tipos_morte');
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Falha ao sincronizar grupos de causas: ${e.toString()}');
    }
  }

  Future<void> _sincronizarCausasMorte() async {
    setState(() {
      _statusMessage = 'Sincronizando Causas de Mortes...';
    });

    try {
      final response = await http.get(
        Uri.parse('$urlSanigado/subtipos_morte.php'),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          final subtipos = data.map<String>((item) => '${item['tipo']}|${item['subtipo']}').toList();

          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/causas-morte-sanigado.json');
          await file.writeAsString(jsonEncode(subtipos));

          return;
        }
        throw Exception('Formato de dados inválido para subtipos_morte');
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Falha ao sincronizar causas de morte: ${e.toString()}');
    }
  }

  Future<void> _sincronizarRetiros() async {
    setState(() {
      _statusMessage = 'Sincronizando Retiros...';
    });

    try {
      final response = await http.get(
        Uri.parse('$urlSanigado/retiros.php'),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          final retiros = data.map<String>((item) => item['retiro'].toString()).toList();

          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/retiros-sanigado.json');
          await file.writeAsString(jsonEncode(retiros));

          return;
        }
        throw Exception('Formato de dados inválido para retiros');
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Falha ao sincronizar retiros: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronizar Tabelas'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sincronização de Tabelas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL do servidor: $urlSanigado',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.contains('Erro')
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sincronizarTabelas,
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar Tabelas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}