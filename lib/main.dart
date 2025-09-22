import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPT-2 Frontend',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _adminTokenController = TextEditingController();

  String _response = '';
  bool _loading = false;
  bool _uploading = false;
  String _uploadMessage = '';
  List<String> _terminal = [];
  Timer? _statusTimer;
  List<String> _models = [];
  String _downloadUrl = '';
  String _baseUrl = 'http://localhost:8000';
  String _adminToken = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = _baseUrl;
    _adminTokenController.text = _adminToken;
    _startStatusPoll();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _controller.dispose();
    _baseUrlController.dispose();
    _adminTokenController.dispose();
    super.dispose();
  }

  void _addTerminal(String line) {
    setState(() {
      _terminal.add(line);
      if (_terminal.length > 200) _terminal.removeAt(0);
    });
  }

  Future<void> _applySettings() async {
    setState(() {
      _baseUrl = _baseUrlController.text.trim();
      _adminToken = _adminTokenController.text.trim();
    });
    _addTerminal('Settings applied: baseUrl=$_baseUrl');
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return _addTerminal('Prompt is empty');
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$_baseUrl/generate');
      final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'prompt': prompt}));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _response = data['generated_text'] ?? res.body;
        });
        _addTerminal('Generation succeeded');
      } else {
        _addTerminal('Generation failed: ${res.statusCode}');
      }
    } catch (e) {
      _addTerminal('Generate error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return _addTerminal('No file picked');
      final file = result.files.first;
      _addTerminal('Picked file: ${file.name} (${file.size} bytes)');

      setState(() => _uploading = true);
      final dio = Dio();
      final uri = '$_baseUrl/upload_model';
      final headers = <String, String>{};
      if (_adminToken.isNotEmpty) headers['Authorization'] = 'Bearer $_adminToken';

      MultipartFile mfile;
      if (file.bytes != null) {
        mfile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
      } else if (file.path != null) {
        mfile = await MultipartFile.fromFile(file.path!, filename: file.name);
      } else {
        _addTerminal('Cannot read selected file');
        setState(() => _uploading = false);
        return;
      }

      final form = FormData.fromMap({'file': mfile});
      final res = await dio.post(uri, data: form, options: Options(headers: headers), onSendProgress: (sent, total) {
        final pct = total > 0 ? ((sent / total) * 100).toStringAsFixed(1) : '0';
        _addTerminal('Upload progress: $pct%');
      });
      _addTerminal('Upload response: ${res.statusCode} ${res.statusMessage}');
    } catch (e) {
      _addTerminal('Upload error: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _fetchModels() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/models'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final models = ((data['models'] as List?) ?? []).map((e) => e.toString()).toList();
        setState(() => _models = models);
        _addTerminal('Models: ${_models.join(', ')}');
      } else {
        _addTerminal('Failed to list models: ${res.statusCode}');
      }
    } catch (e) {
      _addTerminal('Error listing models: $e');
    }
  }

  Future<void> _listAndShowCurrent() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/models'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final modelsList = ((data['models'] as List?) ?? []).map((e) => e.toString()).toList();
        _addTerminal('Models: ${modelsList.join(', ')} | Current: ${data['current']}');
      } else {
        _addTerminal('Failed to get models: ${res.statusCode}');
      }
    } catch (e) {
      _addTerminal('Error: $e');
    }
  }

  Future<void> _selectModel(String name) async {
    try {
      final uri = Uri.parse('$_baseUrl/models/select');
      final headers = {'Content-Type': 'application/json'};
      if (_adminToken.isNotEmpty) headers['Authorization'] = 'Bearer $_adminToken';
      final res = await http.post(uri, headers: headers, body: jsonEncode({'model_name': name}));
      if (res.statusCode == 200) {
        _addTerminal('Model select requested: $name');
      } else {
        _addTerminal('Select failed: ${res.statusCode}');
      }
    } catch (e) {
      _addTerminal('Select error: $e');
    }
  }

  Future<void> _downloadModelByUrl() async {
    if (_downloadUrl.trim().isEmpty) return _addTerminal('Download URL empty');
    try {
      final uri = Uri.parse('$_baseUrl/models/download');
      final headers = {'Content-Type': 'application/json'};
      if (_adminToken.isNotEmpty) headers['Authorization'] = 'Bearer $_adminToken';
      final res = await http.post(uri, headers: headers, body: jsonEncode({'url': _downloadUrl}));
      if (res.statusCode == 200) {
        _addTerminal('Download started');
      } else {
        _addTerminal('Download request failed: ${res.statusCode}');
      }
    } catch (e) {
      _addTerminal('Download error: $e');
    }
  }

  void _startStatusPoll() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final res = await http.get(Uri.parse('$_baseUrl/model_status'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final state = data['state'] ?? 'unknown';
          final message = data['message'] ?? '';
          final progress = data['progress'] ?? 0;
          _addTerminal('Status: $state - $message ($progress%)');
          if (state == 'ready' || state == 'error') {
            // keep polling but user can see final state
          }
        }
      } catch (e) {
        _addTerminal('Status poll error: $e');
      }
    });
  }

  Widget _buildHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Enter a prompt to send to the GPT-2 backend:'),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Once upon a time...',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
          label: const Text('Generate'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _uploading ? null : _uploadModel,
          icon: _uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
          label: const Text('Upload Model'),
        ),
        if (_uploadMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_uploadMessage),
        ],
        const SizedBox(height: 12),
        const Text('Terminal:'),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black12,
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _terminal.map((t) => Text(t)).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Response:'),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: SingleChildScrollView(
            child: SelectableText(
              _response,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModels() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(labelText: 'Backend base URL'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminTokenController,
                    decoration: const InputDecoration(labelText: 'Admin token (optional)'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _applySettings, child: const Text('Apply')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Model Management', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _fetchModels,
                        child: const Text('Refresh Models'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _listAndShowCurrent,
                        child: const Text('Show Current'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(hintText: 'Model download URL (server will fetch)'),
                          onChanged: (v) => _downloadUrl = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _downloadModelByUrl,
                        child: const Text('Download'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_models.isNotEmpty) ...[
                    const Text('Available models:'),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _models.length,
                        itemBuilder: (ctx, idx) {
                          final m = _models[idx];
                          return ListTile(
                            title: Text(m),
                            trailing: ElevatedButton(
                              onPressed: () => _selectModel(m),
                              child: const Text('Select'),
                            ),
                          );
                        },
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPT-2 Frontend')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _selectedIndex == 0 ? _buildHome() : _buildModels(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'Models'),
        ],
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}
