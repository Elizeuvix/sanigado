import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'Home.dart';
import 'Tabelas.dart';

class Configurar extends StatefulWidget {
  const Configurar({Key? key}) : super(key: key);

  @override
  State<Configurar> createState() => _ConfigurarState();
}

class _ConfigurarState extends State<Configurar> {
  final TextEditingController _urlController = TextEditingController();
  String _urlOriginal = "";
  bool _excluindoRegistros = false;

  // Cores e estilos consistentes com o tema do Home
  final Color primaryColor = const Color(0xFF0054A6);
  final Color accentColor = const Color(0xFF0078D7);
  final Color backgroundColor = const Color(0xFFF5F5F5);
  final Color dangerColor = const Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _carregarURL();
    _urlController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _carregarURL() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/url-sanigado.json');

      if (await file.exists()) {
        final conteudo = await file.readAsString();
        setState(() {
          _urlOriginal = conteudo.trim(); // Só o texto da URL
          _urlController.text = _urlOriginal;
        });
      }
    } catch (e) {
      print("Erro ao carregar URL: $e");
    }
  }

  Future<void> _salvarURL() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/url-sanigado.json');

      final url = _urlController.text.trim();
      await file.writeAsString(url); // Salva como texto puro

      setState(() {
        _urlOriginal = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL salva com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Erro ao salvar URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar URL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _excluirRegistrosLocais() async {
    setState(() {
      _excluindoRegistros = true;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mortalidades-sanigado.json');

      if (await file.exists()) {
        await file.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registros locais excluídos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum registro local para excluir'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ Erro ao excluir registros: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir registros: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _excluindoRegistros = false;
      });
    }
  }

  bool get _urlFoiAlterada => _urlController.text.trim() != _urlOriginal;

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
          title: const Text("Manutenção"),
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: "URL do Backend",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "http://192.168.3.196/sanigado/public",
                  prefixIcon: const Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),

              // Botão Salvar URL
              if (_urlFoiAlterada)
                _buildMenuButton(
                  icon: Icons.save,
                  text: "Salvar URL",
                  onPressed: _salvarURL,
                ),

              const SizedBox(height: 24),
              const Divider(thickness: 1),
              const SizedBox(height: 16),

              Text(
                "Gerenciamento de Dados Locais",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // Botão Sincronizar Tabelas
              _buildMenuButton(
                icon: Icons.sync,
                text: "Sincronizar Tabelas",
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Tabelas()),
                    ),
              ),
              const SizedBox(height: 16),

              // Botão Excluir Registros
              _buildMenuButton(
                icon: Icons.delete_forever,
                text: "Excluir Todos os Registros Locais",
                onPressed: _excluindoRegistros ? null : _excluirRegistrosLocais,
                isDanger: true,
                isLoading: _excluindoRegistros,
              ),
              const SizedBox(height: 8),

              Text(
                "Esta ação removerá todos os registros não sincronizados",
                style: TextStyle(color: dangerColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Botão Voltar
              _buildMenuButton(
                icon: Icons.arrow_back,
                text: "Voltar para a Página Inicial",
                onPressed:
                    () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const Home()),
                    ),
                isSecondary: true,
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
    bool isDanger = false,
    bool isSecondary = false,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon:
          isLoading
              ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDanger ? Colors.white : primaryColor,
                ),
              )
              : Icon(icon, size: 24),
      label: Text(text, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isDanger
                ? dangerColor
                : (isSecondary
                    ? Colors.grey.shade300
                    : (onPressed == null ? Colors.grey : primaryColor)),
        foregroundColor:
            isDanger || !isSecondary ? Colors.white : Colors.grey.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}
