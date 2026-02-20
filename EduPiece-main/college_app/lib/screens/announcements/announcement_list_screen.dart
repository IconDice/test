import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import '../../services/api_service.dart';
import 'announcement_chat_screen.dart';

class AnnouncementListScreen extends StatefulWidget {
  @override
  _AnnouncementListScreenState createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  List<dynamic> groups = [];
  bool isLoading = true;

  // Determine if user is Teacher to show "Create" vs "Join"
  bool get isTeacher => ApiService.userRole == 'TEACHER' || ApiService.userRole == 'HOD';

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.fetchMyAnnouncementGroups();
      setState(() {
        groups = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _showActionDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTeacher ? "Create Notice Board" : "Join Notice Board"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isTeacher ? "Group Name (e.g., CS Sem 6)" : "Paste Invite Link (std@... or ad@...)",
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => isLoading = true);
              
              try {
                if (isTeacher && !controller.text.contains("@")) {
                  await ApiService.createAnnouncementGroup(controller.text);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Board Created Successfully!"), backgroundColor: Colors.green));
                } else {
                  await ApiService.joinAnnouncementGroup(controller.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined Successfully!"), backgroundColor: Colors.green));
                }
                _loadGroups(); 
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                setState(() => isLoading = false);
              }
            },
            child: Text(isTeacher ? "Create" : "Join", style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- THE SHARE BOTTOM SHEET ---
  void _showShareBottomSheet(Map group) {
    // 1. We extract the base invite link that the backend sends inside group['invite_link']
    // If for some reason it's missing, we fall back to a blank string to avoid crashes.
    final String baseInviteLink = group['invite_link'] ?? "";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Share Invite Codes", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
              const SizedBox(height: 4),
              Text("Group: ${group['name']}", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              
              // 2. Student Code Card (Dynamically prepends 'std@')
              _buildShareCard(
                title: "Student Join Code",
                code: baseInviteLink.isNotEmpty ? "std@$baseInviteLink" : "Error: No Link", 
                desc: "Students can read and react to announcements.",
                icon: Icons.school,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              
              // 3. Admin Code Card (Dynamically prepends 'ad@')
              _buildShareCard(
                title: "Admin Join Code",
                code: baseInviteLink.isNotEmpty ? "ad@$baseInviteLink" : "Error: No Link", 
                desc: "Admins can post messages, attachments, and polls.",
                icon: Icons.admin_panel_settings,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UI Helper for the Share Cards
  Widget _buildShareCard({required String title, required String code, required String desc, required IconData icon, required MaterialColor color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.shade100, child: Icon(icon, color: color.shade700)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color.shade900, fontSize: 15)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11, color: color.shade700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.shade100)
                  ),
                  child: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0)),
                )
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, color: color.shade700),
            tooltip: "Copy Code",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title Copied to Clipboard!"), backgroundColor: color.shade700));
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notice Boards"), backgroundColor: Colors.teal.shade700),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showActionDialog,
        backgroundColor: Colors.teal.shade700,
        icon: Icon(isTeacher ? Icons.add : Icons.group_add, color: Colors.white),
        label: Text(isTeacher ? "Create Board" : "Join Board", style: const TextStyle(color: Colors.white)),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
        : groups.isEmpty 
          ? const Center(child: Text("No Notice Boards available yet.", style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final group = groups[i];
                final isAdmin = group['role'] == 'ADMIN';
                
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    radius: 24,
                    child: Icon(Icons.campaign, color: Colors.teal.shade800, size: 26),
                  ),
                  title: Text(group['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      isAdmin ? "Admin View" : "Student View", 
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)
                    ),
                  ),
                  
                  // --- THIS IS WHERE THE SHARE ICON IS PLACED ---
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAdmin)
                        IconButton(
                          icon: Icon(Icons.share, color: Colors.teal.shade600),
                          tooltip: "Share Join Codes",
                          onPressed: () => _showShareBottomSheet(group),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AnnouncementChatScreen(
                        groupId: group['id'], 
                        groupName: group['name'], 
                        isAdmin: isAdmin
                      )
                    ));
                  },
                );
              },
            ),
    );
  }
}