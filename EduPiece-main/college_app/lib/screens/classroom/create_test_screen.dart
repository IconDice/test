import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';

class CreateTestScreen extends StatefulWidget {
  final int classId;
  const CreateTestScreen({Key? key, required this.classId}) : super(key: key);

  @override
  _CreateTestScreenState createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  
  List<Map<String, dynamic>> _questions = [
    {
      "question_text": "",
      "options": ["", "", "", ""],
      "correct_option_index": 0,
      "controllers": List.generate(4, (_) => TextEditingController())
    }
  ];

  Future<void> _selectDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startTime : _endTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
    );
    if (time == null) return;

    setState(() {
      final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) _startTime = dt; else _endTime = dt;
    });
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        "question_text": "",
        "options": ["", "", "", ""],
        "correct_option_index": 0,
        "controllers": List.generate(4, (_) => TextEditingController())
      });
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions.removeAt(index);
      });
    }
  }

  Future<void> _submitTest() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_endTime.isBefore(_startTime) || _endTime.isAtSameMomentAs(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End time must be after Start time")));
      return;
    }

    final testPayload = {
      "title": _titleController.text,
      "start_time": _startTime.toUtc().toIso8601String(), // Send in UTC format to match backend
      "end_time": _endTime.toUtc().toIso8601String(),
      "questions": _questions.map((q) {
        List<String> options = (q['controllers'] as List<TextEditingController>)
            .map((c) => c.text).toList();
        
        return {
          "question_text": q['question_text'],
          "options": options,
          "correct_option_index": q['correct_option_index']
        };
      }).toList()
    };

    try {
      final token = await ApiService.getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/classroom/${widget.classId}/tests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(testPayload),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Create New Test"), backgroundColor: Colors.indigo.shade700),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Test Title", 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white
              ),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: const Text("Starts At", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(DateFormat('MMM dd, HH:mm').format(_startTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, color: Colors.indigo),
                    onTap: () => _selectDateTime(true),
                    tileColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: const Text("Ends At", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(DateFormat('MMM dd, HH:mm').format(_endTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.event, color: Colors.red),
                    onTap: () => _selectDateTime(false),
                    tileColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1),
            ),
            const Text("Questions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ..._questions.asMap().entries.map((entry) {
              int idx = entry.key;
              Map q = entry.value;
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: InputDecoration(labelText: "Question ${idx + 1}"),
                              onSaved: (v) => q['question_text'] = v,
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                          ),
                          if (_questions.length > 1)
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeQuestion(idx))
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text("Options (Select the correct one via Radio Button):", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ...List.generate(4, (optIdx) {
                        return Row(
                          children: [
                            Radio<int>(
                              value: optIdx,
                              groupValue: q['correct_option_index'],
                              activeColor: Colors.green,
                              onChanged: (val) => setState(() => q['correct_option_index'] = val),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: q['controllers'][optIdx],
                                decoration: InputDecoration(hintText: "Option ${optIdx + 1}"),
                                validator: (v) => v!.isEmpty ? "Required" : null,
                              ),
                            ),
                          ],
                        );
                      })
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _addQuestion,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), foregroundColor: Colors.indigo),
              icon: const Icon(Icons.add),
              label: const Text("Add Another Question"),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submitTest,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.all(16)),
              child: const Text("PUBLISH TEST", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}