import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'ai_evaluation_screen.dart'; 
import 'classroom/classroom_list_screen.dart';
import 'announcements/announcement_list_screen.dart'; 

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<Map<String, dynamic>> schedule = [];
  bool isLoadingSchedule = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  void _loadSchedule() async {
    try {
      final data = await ApiService.fetchTeacherSchedule();
      setState(() {
        schedule = data;
        isLoadingSchedule = false;
      });
    } catch (e) {
      setState(() => isLoadingSchedule = false);
    }
  }

  void _logout(BuildContext context) {
    ApiService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('EduPiece Teacher'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedule,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          
          // --- DASHBOARD GRID SECTION ---
          _buildDashboardGrid(context),
          
          // --- SECTION TITLE ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Assigned Classes',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // --- SCHEDULE LIST ---
          Expanded(child: _buildScheduleList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.indigo.shade700,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.indigo.shade100,
              child: Icon(Icons.person, size: 35, color: Colors.indigo.shade700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome,',
                  style: TextStyle(color: Colors.indigo.shade100, fontSize: 14),
                ),
                Text(
                  ApiService.currentUserName ?? 'Professor',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- DASHBOARD GRID (AI Evaluator + Classroom + Notice Board) ---
  Widget _buildDashboardGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          // Card 1: AI Evaluator
          Expanded(
            child: _buildFeatureCard(
              context,
              title: 'Evaluator',
              subtitle: 'Auto-grade',
              icon: Icons.psychology,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiEvaluationScreen()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Card 2: Classroom
          Expanded(
            child: _buildFeatureCard(
              context,
              title: 'Classroom',
              subtitle: 'Notes & Tests',
              icon: Icons.school,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ClassroomListScreen()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Card 3: Notice Board (NEW)
          Expanded(
            child: _buildFeatureCard(
              context,
              title: 'Notices',
              subtitle: 'Announce',
              icon: Icons.campaign,
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AnnouncementListScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withAlpha((0.08 * 255).round()),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: color.shade700),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return isLoadingSchedule
        ? const Center(child: CircularProgressIndicator())
        : schedule.isEmpty
            ? Center(
                child: Text(
                  'No classes assigned',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: schedule.length,
                itemBuilder: (context, index) {
                  final item = schedule[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.class_, color: Colors.indigo.shade700),
                      ),
                      title: Text(
                        item['subject_name'] ?? 'Class',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${item['day_of_week']} • ${item['start_time']}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  );
                },
              );
  }
}