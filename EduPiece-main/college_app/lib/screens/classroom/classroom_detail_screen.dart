import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../models/classroom_models.dart';
import 'create_test_screen.dart';
import 'take_test_screen.dart';
import 'analytics_screen.dart';

class ClassroomDetailScreen extends StatelessWidget {
  final Classroom classroom;

  const ClassroomDetailScreen({Key? key, required this.classroom}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(classroom.name),
          backgroundColor: Colors.indigo.shade700,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.book), text: "Notes"),
              Tab(icon: Icon(Icons.assignment), text: "Assignments"),
              Tab(icon: Icon(Icons.quiz), text: "Tests"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Notes
            _ResourceTab(
              classId: classroom.id, 
              isTeacher: classroom.isTeacher, 
              type: 'notes'
            ),
            // Tab 2: Assignments
            _ResourceTab(
              classId: classroom.id, 
              isTeacher: classroom.isTeacher, 
              type: 'assignments'
            ),
            // Tab 3: Tests
            _TestsTab(
              classId: classroom.id, 
              isTeacher: classroom.isTeacher
            ),
          ],
        ),
      ),
    );
  }
}

// --- REUSABLE TAB WIDGET FOR NOTES & ASSIGNMENTS ---

class _ResourceTab extends StatefulWidget {
  final int classId;
  final bool isTeacher;
  final String type; 

  const _ResourceTab({
    required this.classId,
    required this.isTeacher,
    required this.type,
  });

  @override
  State<_ResourceTab> createState() => _ResourceTabState();
}

class _ResourceTabState extends State<_ResourceTab> {
  List<dynamic> items = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/classroom/${widget.classId}/${widget.type}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          items = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // --- TEACHER: UPLOAD RESOURCE (WITH TIME PICKER) ---
  Future<void> _pickAndUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      final titleController = TextEditingController();
      DateTime? selectedDateTime;

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Upload ${widget.type == 'notes' ? 'Note' : 'Assignment'}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: "Title"),
                  ),
                  if (widget.type == 'assignments') ...[
                    SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: Colors.grey.shade100,
                      title: Text(selectedDateTime == null 
                        ? "Select Date & Time" 
                        : DateFormat('MMM dd, yyyy - HH:mm').format(selectedDateTime!)),
                      trailing: Icon(Icons.schedule, color: Colors.indigo), // Fixed Icon Here
                      onTap: () async {
                        // 1. Pick Date
                        final date = await showDatePicker(
                          context: context, 
                          initialDate: DateTime.now(), 
                          firstDate: DateTime.now(), 
                          lastDate: DateTime(2030)
                        );
                        if (date != null) {
                          // 2. Pick Time
                          final time = await showTimePicker(
                            context: context, 
                            initialTime: TimeOfDay.now()
                          );
                          if (time != null) {
                            setStateDialog(() {
                              selectedDateTime = DateTime(
                                date.year, date.month, date.day, 
                                time.hour, time.minute
                              );
                            });
                          }
                        }
                      },
                    )
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () async {
                    if (titleController.text.isEmpty) return;
                    if (widget.type == 'assignments' && selectedDateTime == null) return;
                    
                    Navigator.pop(ctx);
                    _uploadFile(file, titleController.text, selectedDateTime);
                  },
                  child: Text("Upload", style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        ),
      );
    }
  }

  Future<void> _uploadFile(File file, String title, DateTime? deadline) async {
    setState(() => isLoading = true);
    try {
      await ApiService.uploadClassroomFile(
        classId: widget.classId,
        title: title,
        file: file,
        type: widget.type,
        deadline: deadline,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Successful")));
      _fetchItems(); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => isLoading = false);
    }
  }

  // --- STUDENT: SUBMIT ASSIGNMENT ---
  Future<void> _studentSubmitAssignment(int assignId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() => isLoading = true);
      try {
        await ApiService.submitAssignment(assignId: assignId, file: file);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Assignment Submitted Successfully!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        _fetchItems(); // Refresh to show "Submitted" status
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _downloadFile(String url) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$url');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open file")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              onPressed: _pickAndUpload,
              backgroundColor: Colors.indigo,
              icon: Icon(Icons.upload_file),
              label: Text(widget.type == 'notes' ? "Upload Note" : "Create Assignment"),
            )
          : null,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(child: Text("No ${widget.type} available yet.", style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final isAssignment = widget.type == 'assignments';
                    
                    DateTime? deadline;
                    bool isPassed = false;
                    bool isSubmitted = item['is_submitted'] ?? false;

                    if (isAssignment && item['deadline'] != null) {
                      deadline = DateTime.parse(item['deadline']);
                      isPassed = DateTime.now().isAfter(deadline);
                    }

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ROW 1: Icon, Title, and Download Button (Always available)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isAssignment ? Colors.orange.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                  child: Icon(
                                    isAssignment ? Icons.assignment : Icons.description, 
                                    color: isAssignment ? Colors.orange : Colors.blue
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (isAssignment && deadline != null) ...[
                                        SizedBox(height: 4),
                                        Text(
                                          "Due: ${DateFormat('MMM dd, yyyy - HH:mm').format(deadline.toLocal())}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isPassed && !isSubmitted ? Colors.red : Colors.grey.shade700
                                          )
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.download_rounded, color: Colors.indigo),
                                  tooltip: "Download PDF",
                                  onPressed: () => _downloadFile(item['file_url']),
                                )
                              ],
                            ),
                            
                            // ROW 2: Contextual Actions (Teacher Analytics OR Student Submit)
                            if (isAssignment) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Divider(height: 1),
                              ),
                              SizedBox(height: 12),
                              
                              if (widget.isTeacher)
                                // TEACHER VIEW
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => AnalyticsScreen(
                                          contentId: item['id'], 
                                          title: item['title'], 
                                          type: 'assignments'
                                        )
                                      ));
                                    },
                                    icon: Icon(Icons.analytics, color: Colors.indigo),
                                    label: Text("View Submissions", style: TextStyle(color: Colors.indigo)),
                                  ),
                                )
                              else
                                // STUDENT VIEW
                                isSubmitted 
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text("Turned In", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15))
                                      ],
                                    )
                                  : isPassed 
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error_outline, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text("Missing (Deadline Passed)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15))
                                          ],
                                        )
                                      : SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _studentSubmitAssignment(item['id']),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                                            icon: Icon(Icons.upload_file, color: Colors.white),
                                            label: Text("Upload Submission (PDF)", style: TextStyle(color: Colors.white)),
                                          ),
                                        )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// --- DEDICATED TAB WIDGET FOR TESTS ---

class _TestsTab extends StatefulWidget {
  final int classId;
  final bool isTeacher;
  const _TestsTab({required this.classId, required this.isTeacher});

  @override
  State<_TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<_TestsTab> {
  List<dynamic> tests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  Future<void> _fetchTests() async {
    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/classroom/${widget.classId}/tests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          tests = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _onTestTap(Map test) {
    if (widget.isTeacher) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => AnalyticsScreen(
          contentId: test['id'], 
          title: test['title'], 
          type: 'tests'
        )
      ));
    } else {
      final startTime = DateTime.parse(test['start_time']);
      final endTime = DateTime.parse(test['end_time']);
      final now = DateTime.now();

      if (now.isBefore(startTime)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Test hasn't started yet.")));
      } else if (now.isAfter(endTime)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Test has ended.")));
      } else {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TakeTestScreen(testId: test['id'], title: test['title'])
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CreateTestScreen(classId: widget.classId)
                ));
                if (result == true) _fetchTests();
              },
              icon: Icon(Icons.add),
              label: Text("Create Test"),
              backgroundColor: Colors.indigo,
            )
          : null,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : tests.isEmpty
              ? Center(child: Text("No tests scheduled"))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: tests.length,
                  itemBuilder: (ctx, i) {
                    final test = tests[i];
                    final start = DateTime.parse(test['start_time']);
                    final end = DateTime.parse(test['end_time']);
                    return Card(
                      elevation: 2,
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade50,
                          child: Icon(Icons.quiz, color: Colors.purple),
                        ),
                        title: Text(test['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text("Starts: ${DateFormat('MMM dd, HH:mm').format(start.toLocal())}"),
                            Text("Ends: ${DateFormat('MMM dd, HH:mm').format(end.toLocal())}"),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _onTestTap(test),
                      ),
                    );
                  },
                ),
    );
  }
}