import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../models/classroom_models.dart';
import 'classroom_detail_screen.dart';

class ClassroomListScreen extends StatefulWidget {
  // const ClassroomListScreen({super.key});

  @override
  _ClassroomListScreenState createState() => _ClassroomListScreenState();
}

class _ClassroomListScreenState extends State<ClassroomListScreen> {
  List<Classroom> classrooms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClassrooms();
  }

  Future<void> fetchClassrooms() async {
    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/classroom/my-classes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          classrooms = data.map((e) => Classroom.fromJson(e)).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _showJoinCreateDialog() {
    final isTeacher = ApiService.userRole == "TEACHER";
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isTeacher ? "Create New Class" : "Join a Class"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isTeacher ? "Enter Class Name" : "Enter 6-digit Code",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => isLoading = true);
              
              final url = isTeacher ? '/create' : '/join';
              final body = isTeacher
                  ? jsonEncode({'name': controller.text})
                  : jsonEncode({'code': controller.text});

              try {
                final token = await ApiService.getToken();
                await http.post(
                  Uri.parse('${AppConfig.baseUrl}/api/classroom$url'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token'
                  },
                  body: body,
                );
                fetchClassrooms();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Action failed: $e")),
                );
                setState(() => isLoading = false);
              }
            },
            child: Text("Confirm"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("My Classrooms"),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showJoinCreateDialog,
        backgroundColor: Colors.indigo,
        icon: Icon(Icons.add),
        label: Text(ApiService.userRole == "TEACHER" ? "Create Class" : "Join Class"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : classrooms.isEmpty 
              ? Center(child: Text("No classrooms found. Join or create one!", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: classrooms.length,
                  itemBuilder: (ctx, i) {
                    final cls = classrooms[i];
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.08),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(20),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade50,
                          child: Text(cls.name[0].toUpperCase(), 
                              style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(cls.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            if (cls.isTeacher)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200)
                                ),
                                child: SelectableText("Code: ${cls.joinCode}", 
                                    style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                              ),
                            if (!cls.isTeacher)
                              Text("Student Access", style: TextStyle(color: Colors.green)),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ClassroomDetailScreen(classroom: cls)
                          ));
                        },
                      ),
                    );
                  },
                ),
    );
  }
}