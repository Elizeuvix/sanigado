import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'Home.dart';

class Mortalidade extends StatefulWidget {
  const Mortalidade({Key? key}) : super(key: key);

  @override
  _MortalidadeState createState() => _MortalidadeState();
}

class _MortalidadeState extends State<Mortalidade> {
  final TextEditingController _brincoController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _laudoController = TextEditingController();
  final TextEditingController _localidadeController = TextEditingController();
  final TextEditingController _notificanteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  File? _selectedImage;
  Uint8List? _imageBytes;
  String? _grupoCausa, _causaMorte, _retiro, _notificante;
  List<String> gruposCausas = [], retiros = [];
  Map<String, List<String>> _causasMorteFiltradas = {};
  List<String> _causasMorteDisponiveis = [];

  final Color primaryColor = const Color(0xFF0054A6);
  final Color accentColor = const Color(0xFF0078D7);
  final Color backgroundColor = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    _loadUsuario();
  }

  Future<String> _getFilePath(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename';
  }

  Future<void> _loadUsuario() async {
    try {
      final path = await _getFilePath('usuario-sanigado.json');
      final file = File(path);
      if (await file.exists()) {
        final jsonData = jsonDecode(await file.readAsString());
        setState(() {
          _notificante = jsonData['nome'] ?? 'Usuário';
          _notificanteController.text = jsonData['nome'] ?? 'Usuário';
        });
      }
    } catch (e) {
      _showError('Erro ao carregar usuário: ${e.toString()}');
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      gruposCausas = await _loadJsonList('grupo-causas-sanigado.json');
      retiros = await _loadJsonList('retiros-sanigado.json');
      _causasMorteFiltradas = await _loadCausasMorteFiltradas();
      setState(() {});
    } catch (e) {
      _showError('Erro ao carregar dados: ${e.toString()}');
    }
  }

  Future<Map<String, List<String>>> _loadCausasMorteFiltradas() async {
    final Map<String, List<String>> result = {};
    try {
      final path = await _getFilePath('causas-morte-sanigado.json');
      final file = File(path);
      if (await file.exists()) {
        final List<dynamic> jsonData = jsonDecode(await file.readAsString());
        for (var item in jsonData) {
          if (item is String) {
            final parts = item.split('|');
            if (parts.length == 2) {
              final grupo = parts[0];
              final causa = parts[1];
              result[grupo] = [...result[grupo] ?? [], causa];
            }
          }
        }
      }
    } catch (e) {
      _showError('Erro ao carregar causas: ${e.toString()}');
    }
    return result;
  }

  Future<List<String>> _loadJsonList(String fileName) async {
    try {
      final path = await _getFilePath(fileName);
      final file = File(path);
      if (await file.exists()) {
        final List<dynamic> jsonData = jsonDecode(await file.readAsString());
        return jsonData.cast<String>();
      }
    } catch (e) {
      _showError('Erro ao carregar $fileName: ${e.toString()}');
    }
    return [];
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Mostrar opções em um bottom sheet
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );

      if (source == null) return;

      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null) {
        final originalBytes = await pickedFile.readAsBytes();

        final compressedBytes = await FlutterImageCompress.compressWithList(
          originalBytes,
          minHeight: 1024,
          minWidth: 1024,
          quality: 85,
          format: CompressFormat.jpeg,
          keepExif: true,
        );

        if (compressedBytes == null || compressedBytes.isEmpty) {
          throw Exception('Falha na compressão - imagem vazia');
        }

        setState(() {
          _imageBytes = compressedBytes;
          if (!kIsWeb) {
            _selectedImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      _showError('Erro ao selecionar imagem: ${e.toString()}');
    }
  }

  Future<void> _selectDateTime() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        final TimeOfDay? time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          setState(() {
            _selectedDate = DateTime(
              picked.year,
              picked.month,
              picked.day,
              time.hour,
              time.minute,
            );
          });
        }
      }
    } catch (e) {
      _showError('Erro ao selecionar data: ${e.toString()}');
    }
  }

  Future<void> _salvarRegistro() async {
    preencherCampos();
    if (!_validarCampos()) return;

    print("VALIDARCAMPOS: $_validarCampos");
    try {
      final path = await _getFilePath('mortalidades-sanigado.json');
      final file = File(path);
      List<dynamic> registros = await _carregarRegistrosExistentes(file);

      final novoRegistro = _criarNovoRegistro();
      registros.add(novoRegistro);

      await _salvarRegistrosNoArquivo(file, registros);
      _showSuccess('Registro salvo com sucesso!');
      _resetForm();
    } catch (e) {
      _showError('Erro grave ao salvar: ${e.toString()}');
    }
  }

  bool _validarCampos() {

    if (_brincoController.text.isEmpty) {
      _showError('O campo Brinco é obrigatório');
      return false;
    }

    if (_grupoCausa == null || _grupoCausa!.isEmpty) {
      _showError('Selecione um Grupo de Causas');
      return false;
    }

    if (_causaMorte == null || _causaMorte!.isEmpty) {
      _showError('Selecione uma Causa da Morte');
      return false;
    }

    if (_retiro == null || _retiro!.isEmpty) {
      _showError('Selecione o Retiro');
      return false;
    }

    if (_localidadeController.text.isEmpty) {
      _showError('O campo Localidade é obrigatório');
      return false;
    }

    // Campos adicionais que podem ser obrigatórios dependendo dos requisitos
    if (_descricaoController.text.isEmpty) {
      _showError('O campo Descrição é obrigatório');
      return false;
    }

    if (_imageBytes == null) {
      _showError('É obrigatório ter uma foto');
      return false;
    }

    return true;
  }

  Future<List<dynamic>> _carregarRegistrosExistentes(File file) async {
    if (!await file.exists()) return [];
    try {
      final conteudo = await file.readAsString();
      if (conteudo.trim().isEmpty) return [];
      return jsonDecode(conteudo) as List<dynamic>;
    } catch (e) {
      await file.writeAsString('[]');
      return [];
    }
  }

  Map<String, dynamic> _criarNovoRegistro() {
    return {
      "brinco": _brincoController.text,
      "grupo_causa": _grupoCausa,
      "causa_morte": _causaMorte,
      "causa_completa": "$_grupoCausa|$_causaMorte",
      "descricao": _descricaoController.text,
      "data": DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate),
      "laudo": _laudoController.text,
      "retiro": _retiro,
      "localidade": _localidadeController.text,
      "notificante": _notificante,
      "foto": _imageBytes != null ? base64Encode(_imageBytes!) : null,
    };
  }

  Future<void> _salvarRegistrosNoArquivo(
    File file,
    List<dynamic> registros,

  ) async {
    preencherCampos();
    await file.writeAsString(
      jsonEncode(registros),
      flush: true,
      mode: FileMode.write,
    );
  }

  void _resetForm() {
    _brincoController.clear();
    _descricaoController.clear();
    _laudoController.clear();
    _localidadeController.clear();
    setState(() {
      _grupoCausa = _causaMorte = _retiro = null;
      _selectedImage = null;
      _imageBytes = null;
      _selectedDate = DateTime.now();
      _causasMorteDisponiveis = [];
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
        items:
            items
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Registrar Mortalidade'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(_brincoController, "Brinco"),
            _buildDropdown("Grupo de Causas", _grupoCausa, gruposCausas, (val) {
              setState(() {
                _grupoCausa = val;
                _causaMorte = null;
                _causasMorteDisponiveis =
                    val != null ? _causasMorteFiltradas[val] ?? [] : [];
              });
            }),
            if (_grupoCausa != null)
              _buildDropdown(
                "Causa da Morte",
                _causaMorte,
                _causasMorteDisponiveis,
                (val) {
                  setState(() => _causaMorte = val);
                },
              ),
            _buildTextField(_descricaoController, "Descrição", maxLines: 3),
            _buildTextField(_laudoController, "Laudo", maxLines: 3),
            _buildDropdown(
              "Retiro",
              _retiro,
              retiros,
              (val) => setState(() => _retiro = val),
            ),
            _buildTextField(_localidadeController, "Localidade"),
            _buildTextField(_notificanteController, "Notificante"),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text("Tirar Foto"),
            ),
            if (_imageBytes != null)
              Column(
                children: [
                  Image.memory(_imageBytes!, height: 200),
                  TextButton(
                    onPressed: () => setState(() => _imageBytes = null),
                    child: const Text('Remover Foto'),
                  ),
                ],
              ),
            ElevatedButton(
              onPressed: _salvarRegistro,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("SALVAR REGISTRO"),
            ),
          ],
        ),
      ),
    );
  }

  void preencherCampos() {
    if (_laudoController.text.isEmpty) {
      _laudoController.text = "Não preenchido";
    }

    if (_descricaoController.text.isEmpty) {
      _descricaoController.text = "Não preenchido";
    }

    if (_localidadeController.text.isEmpty) {
      _localidadeController.text = "Não preenchido";
    }
  }
}
