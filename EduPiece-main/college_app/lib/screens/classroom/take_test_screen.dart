import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/app_config.dart';
import '../../services/api_service.dart';

class TakeTestScreen extends StatefulWidget {
  final int testId;
  final String title;

  const TakeTestScreen({Key? key, required this.testId, required this.title}) : super(key: key);

  @override
  _TakeTestScreenState createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends State<TakeTestScreen> {
  List<dynamic> questions = [];
  Map<int, int> answers = {}; // questionIndex -> optionIndex
  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/classroom/tests/${widget.testId}/questions'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          questions = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        _showError("Could not load questions. Check if test has started.");
      }
    } catch (e) {
      _showError("Error loading test: $e");
    }
  }

  Future<void> _submitAnswers() async {
    setState(() => isSubmitting = true);
    // Prepare answers array matching question order
    List<int> answerList = [];
    for (int i = 0; i < questions.length; i++) {
      answerList.add(answers[i] ?? -1); // -1 for unattempted
    }

    try {
      final token = await ApiService.getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/classroom/tests/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          "test_id": widget.testId,
          "answers": answerList
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _showResultDialog(result['score'], result['total']);
      } else {
        _showError("Submission failed: ${response.body}");
        setState(() => isSubmitting = false);
      }
    } catch (e) {
      _showError("Error submitting: $e");
      setState(() => isSubmitting = false);
    }
  }

  void _showResultDialog(int score, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Test Submitted"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("You scored", style: TextStyle(fontSize: 16)),
            Text("$score / $total", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Go back to Detail Screen
            },
            child: Text("Close"),
          )
        ],
      ),
    );
  }

  void _showError(String msg) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: questions.length,
                    itemBuilder: (ctx, i) {
                      final q = questions[i];
                      final options = List<String>.from(q['options']);
                      return Card(
                        margin: EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Q${i + 1}. ${q['question_text']}", 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Divider(),
                              ...options.asMap().entries.map((entry) {
                                return RadioListTile<int>(
                                  title: Text(entry.value),
                                  value: entry.key,
                                  groupValue: answers[i],
                                  onChanged: (val) {
                                    setState(() => answers[i] = val!);
                                  },
                                );
                              }).toList()
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  color: Colors.white,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submitAnswers,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                      backgroundColor: Colors.indigo
                    ),
                    child: isSubmitting 
                        ? CircularProgressIndicator(color: Colors.white) 
                        : Text("SUBMIT TEST", style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                )
              ],
            ),
    );
  }
}