import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../models/attendance_entry.dart';
import '../models/medical_entry.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static String? _token;
  static String? userRole;
  static String? currentUserName;
  static String? currentUserId;

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    _token = await _storage.read(key: 'auth_token');
    return _token;
  }

  // --- AUTH METHODS ---
  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        userRole = data['role'];
        currentUserName = data['full_name'];
        currentUserId = data['user_id'] ?? username; 
        await _storage.write(key: 'auth_token', value: _token!);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    _token = null;
    userRole = null;
    currentUserName = null;
    currentUserId = null;
    await _storage.delete(key: 'auth_token');
  }

  // --- ATTENDANCE & SCHEDULE METHODS ---
  static Future<List<Map<String, dynamic>>> fetchTeacherSchedule() async {
    final fid = currentUserId; 
    if (fid == null) return [];
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/api/attendance/teacher/schedule/$fid'), headers: _getHeaders());
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      return [];
    } catch (e) { return []; }
  }

  static Future<List<AttendanceEntry>> fetchRollList(String classId, String subjectId) async {
    final response = await http.post(Uri.parse('${AppConfig.baseUrl}/api/attendance/roll-list'), headers: _getHeaders(), body: jsonEncode({'class_id': classId, 'subject_id': subjectId}));
    if (response.statusCode == 200) {
      final List rolls = jsonDecode(response.body)['roll_numbers'];
      return rolls.map((r) => AttendanceEntry(rollNo: r.toString())).toList();
    }
    throw Exception('Failed to fetch rolls');
  }

  static Future<void> submitAttendance(String subjectId, DateTime date, List<AttendanceEntry> entries) async {
    final payload = {'subject_id': subjectId, 'date': date.toIso8601String().split('T').first, 'records': entries.map((e) => e.toJson()).toList()};
    final response = await http.post(Uri.parse('${AppConfig.baseUrl}/api/attendance/submit'), headers: _getHeaders(), body: jsonEncode(payload));
    if (response.statusCode != 200) throw Exception('Submit failed');
  }

  static Future<Map<String, dynamic>> fetchStudentStats(String studentId) async {
    final response = await http.get(Uri.parse('${AppConfig.baseUrl}/api/attendance/student/stats/$studentId'), headers: _getHeaders());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load stats');
  }

  // --- MEDICAL METHODS ---
  static Future<String> submitMedical({
    required String studentRollNo, required String departmentId, required DateTime fromDate, required DateTime toDate, required String reason, required File pdfFile,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/medical/submit'));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields.addAll({'student_roll_no': studentRollNo, 'department_id': departmentId, 'from_date': fromDate.toIso8601String().split('T').first, 'to_date': toDate.toIso8601String().split('T').first, 'reason': reason});
    request.files.add(await http.MultipartFile.fromPath('file', pdfFile.path, contentType: MediaType('application', 'pdf')));
    var response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) return jsonDecode(response.body)['request_id'];
    throw Exception('Medical submit failed');
  }

  static Future<List<MedicalEntry>> fetchPendingMedical(String departmentId) async {
    final response = await http.get(Uri.parse('${AppConfig.baseUrl}/api/medical/hod/pending?department_id=$departmentId'), headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((r) => MedicalEntry(requestId: r['request_id'], studentRollNo: r['student_roll_no'], fromDate: DateTime.parse(r['from_date']), toDate: DateTime.parse(r['to_date']), status: r['status'], hodRemark: r['hod_remark'], reason: r['reason'] ?? '', documentPath: r['document_path'] ?? '', ocrText: r['ocr_text'], ocrStatus: r['ocr_status'])).toList();
    }
    throw Exception('Fetch failed');
  }

  static Future<void> reviewMedical(String requestId, String action, String? remark) async {
    final response = await http.post(Uri.parse('${AppConfig.baseUrl}/api/medical/hod/review'), headers: _getHeaders(), body: jsonEncode({'request_id': requestId, 'action': action, 'remark': remark ?? ''}));
    if (response.statusCode != 200) throw Exception('Review failed');
  }

  // --- CLASSROOM METHODS ---
  static Future<void> uploadClassroomFile({required int classId, required String title, required File file, required String type, DateTime? deadline}) async {
    final token = await getToken();
    var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/classroom/$classId/$type'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    if (deadline != null) request.fields['deadline'] = deadline.toUtc().toIso8601String();
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Upload failed');
  }

  static Future<void> submitAssignment({required int assignId, required File file}) async {
    final token = await getToken();
    var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/classroom/assignments/$assignId/submit'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Submission failed');
  }

  // --- ANNOUNCEMENT METHODS ---
  
  static Future<List<dynamic>> fetchMyAnnouncementGroups() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/announce/groups/my'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> createAnnouncementGroup(String name) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/announce/groups/create'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({"name": name}),
    );
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // UPDATED: Now processes the prefixes and extracts the requested role!
  static Future<void> joinAnnouncementGroup(String code) async {
    final token = await getToken();
    
    String cleanCode = code;
    String requestedRole = "MEMBER";
    
    // Automatically parse the format std@... or ad@...
    if (code.startsWith("std@")) {
      cleanCode = code.substring(4);
      requestedRole = "MEMBER";
    } else if (code.startsWith("ad@")) {
      cleanCode = code.substring(3);
      requestedRole = "ADMIN";
    }

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/announce/groups/join'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        "invite_link": cleanCode,
        "role": requestedRole // Sending the role payload dynamically so your backend knows which level of access to grant
      }),
    );
    if (response.statusCode != 200) throw Exception(jsonDecode(response.body)['detail'] ?? "Join failed");
  }

  static Future<List<dynamic>> fetchAnnouncements(int groupId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/announce/groups/$groupId/messages'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> postAnnouncement({
    required int groupId, 
    required String type, 
    String? content, 
    required List<String> tags, 
    List<String>? pollOptions,
    File? file,
  }) async {
    final token = await getToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/api/announce/groups/$groupId/announce');
    
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    
    request.fields['message_type'] = type;
    request.fields['tags'] = jsonEncode(tags);
    
    if (content != null && content.isNotEmpty) {
      request.fields['content'] = content;
    }
    
    if (pollOptions != null && pollOptions.isNotEmpty) {
      request.fields['poll_options'] = jsonEncode(pollOptions);
    }
    
    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }

    final response = await http.Response.fromStream(await request.send());
    
    if (response.statusCode != 200) {
      throw Exception("Failed to post: ${response.body}");
    }
  }

  static Future<void> reactToAnnouncement(int announceId, String emoji) async {
    final token = await getToken();
    await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/announce/react'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({"announcement_id": announceId, "emoji": emoji}),
    );
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }
}