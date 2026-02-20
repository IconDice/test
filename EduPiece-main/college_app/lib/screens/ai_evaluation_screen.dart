import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class AiEvaluationScreen extends StatefulWidget {
  const AiEvaluationScreen({super.key});

  @override
  State<AiEvaluationScreen> createState() => _AiEvaluationScreenState();
}

class _AiEvaluationScreenState extends State<AiEvaluationScreen> {
  File? _selectedImage;
  final _picker = ImagePicker();
  final _keywordController = TextEditingController();
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _result = null; // Reset previous result
      });
    }
  }

  Future<void> _analyzeAnswer() async {
    if (_selectedImage == null || _keywordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select image and enter keywords')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/evaluation/evaluate'),
      );

      request.fields['keywords'] = _keywordController.text;
      request.fields['total_marks'] = '10';

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        _selectedImage!.path,
      ));

      var response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        setState(() {
          _result = jsonDecode(response.body);
        });
      } else {
        throw Exception('Server Error: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Analysis Failed: $e')),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('AI Answer Checker'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Image Picker Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => _pickImage(ImageSource.gallery),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: 50, color: Colors.indigo.shade300),
                            const SizedBox(height: 10),
                            Text('Tap to upload Answer Sheet',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Keyword Input
            TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                labelText: 'Expected Keywords (Answer Key)',
                hintText: 'e.g., polymorphism, inheritance, class, object',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.vpn_key),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // 3. Action Button
            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeAnswer,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Evaluate with AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Result Section
            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final int score = _result!['score'];
    final int total = _result!['total_marks'];
    final List missing = _result!['missing_keywords'];
    final String feedback = _result!['feedback'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.indigo.withAlpha((0.1*255).round()),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        children: [
          const Text('AI Evaluation Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: score / total,
                backgroundColor: Colors.grey.shade200,
                color: score > 7 ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 20),
              Text(
                '$score / $total',
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(feedback,
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          if (missing.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Missing Concepts:',
                  style: TextStyle(
                      color: Colors.red.shade700, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: missing
                  .map((k) => Chip(
                        label: Text(k),
                        backgroundColor: Colors.red.shade50,
                        labelStyle: TextStyle(color: Colors.red.shade700),
                      ))
                  .toList(),
            ),
          ]
        ],
      ),
    );
  }
}
