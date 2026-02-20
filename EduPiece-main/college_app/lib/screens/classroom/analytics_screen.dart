import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final int contentId;
  final String title;
  final String type; // 'assignments' or 'tests'

  const AnalyticsScreen({
    Key? key, 
    required this.contentId, 
    required this.title, 
    required this.type
  }) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<dynamic> submissions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final token = await ApiService.getToken();
      final endpoint = widget.type == 'assignments' 
          ? 'assignments/${widget.contentId}/submissions' 
          : 'tests/${widget.contentId}/results';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/classroom/$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          submissions = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.title} - Submissions"),
        backgroundColor: Colors.indigo,
      ),
      body: isLoading 
          ? Center(child: CircularProgressIndicator())
          : submissions.isEmpty
              ? Center(child: Text("No submissions yet."))
              : ListView.builder(
                  itemCount: submissions.length,
                  itemBuilder: (ctx, i) {
                    final sub = submissions[i];
                    final date = DateTime.parse(sub['submitted_at']);
                    
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          child: Text(sub['student_name'][0]),
                        ),
                        title: Text(sub['student_name']),
                        subtitle: Text("Submitted: ${DateFormat('MMM dd, HH:mm').format(date.toLocal())}"),
                        trailing: widget.type == 'tests'
                            ? Text(
                                "${sub['score']} / ${sub['total']}",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                              )
                            : IconButton(
                                icon: Icon(Icons.download, color: Colors.blue),
                                onPressed: () => launchUrl(Uri.parse('${AppConfig.baseUrl}${sub['file_url']}')),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}