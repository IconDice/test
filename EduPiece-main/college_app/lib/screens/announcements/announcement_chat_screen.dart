import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../config/app_config.dart';

class AnnouncementChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final bool isAdmin;

  const AnnouncementChatScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _AnnouncementChatScreenState createState() => _AnnouncementChatScreenState();
}

class _AnnouncementChatScreenState extends State<AnnouncementChatScreen> {
  // --- NEW: Variables for Instant Filtering ---
  List<dynamic> _allMessages = [];
  List<dynamic> _displayedMessages = [];
  Set<String> _availableTags = {};
  String? _selectedTagFilter;
  bool _isFilterVisible = false;

  bool isLoading = true;
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final data = await ApiService.fetchAnnouncements(widget.groupId);
      setState(() {
        _allMessages = data;
        
        // Extract unique tags from all messages
        _availableTags.clear();
        for (var msg in _allMessages) {
          for (var tag in (msg['tags'] as List? ?? [])) {
            _availableTags.add(tag.toString());
          }
        }
        
        _applyFilter(); // Apply filter if one is selected
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // --- NEW: Apply Tag Filter Locally ---
  void _applyFilter() {
    if (_selectedTagFilter == null) {
      _displayedMessages = List.from(_allMessages);
    } else {
      _displayedMessages = _allMessages.where((msg) {
        final tags = (msg['tags'] as List? ?? []).map((e) => e.toString()).toList();
        return tags.contains(_selectedTagFilter);
      }).toList();
    }
  }

  void _showTagSelectionDialog(String type, {String? content, File? file, List<String>? pollOptions}) {
    List<String> selectedTags = [];
    final List<String> defaultTags = ["Notice", "Time Table", "Placement", "Internship", "Urgent", "Exam"];
    final TextEditingController customTagController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Add Tags to Send"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select at least one tag for this announcement:", style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: defaultTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: Colors.teal.shade100,
                        checkmarkColor: Colors.teal.shade800,
                        onSelected: (val) {
                          setStateDialog(() {
                            if (val) selectedTags.add(tag);
                            else selectedTags.remove(tag);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                  TextField(
                    controller: customTagController,
                    decoration: InputDecoration(
                      hintText: "Or type a custom tag...",
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.teal),
                        onPressed: () {
                          final newTag = customTagController.text.trim();
                          if (newTag.isNotEmpty && !defaultTags.contains(newTag)) {
                            setStateDialog(() {
                              defaultTags.add(newTag);
                              selectedTags.add(newTag);
                              customTagController.clear();
                            });
                          }
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  if (selectedTags.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 1 tag"), backgroundColor: Colors.orange));
                    return;
                  }
                  
                  Navigator.pop(ctx);
                  setState(() => isLoading = true);
                  
                  try {
                    await ApiService.postAnnouncement(
                      groupId: widget.groupId,
                      type: type,
                      content: content,
                      tags: selectedTags,
                      file: file,
                      pollOptions: pollOptions,
                    );
                    _msgController.clear();
                    _fetchMessages();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                    setState(() => isLoading = false);
                  }
                },
                child: const Text("Post to Group", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      ),
    );
  }

  void _showPollCreationDialog() {
    final questionController = TextEditingController();
    List<TextEditingController> optionControllers = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Create Poll"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(labelText: "Poll Question", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(optionControllers.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: optionControllers[i], decoration: InputDecoration(hintText: "Option ${i + 1}", isDense: true))),
                        if (optionControllers.length > 2)
                          IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setStateDialog(() => optionControllers.removeAt(i))),
                      ]
                    )
                  )),
                  if (optionControllers.length < 5)
                    TextButton.icon(
                      icon: const Icon(Icons.add), label: const Text("Add Option"), 
                      onPressed: () => setStateDialog(() => optionControllers.add(TextEditingController()))
                    ),
                ]
              )
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () {
                  if (questionController.text.isEmpty || optionControllers.any((c) => c.text.isEmpty)) return;
                  Navigator.pop(ctx);
                  _showTagSelectionDialog("POLL", content: questionController.text, pollOptions: optionControllers.map((c) => c.text).toList());
                },
                child: const Text("Next", style: TextStyle(color: Colors.white)),
              )
            ]
          );
        }
      )
    );
  }

  Future<void> _pickFile(bool isImage) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: isImage ? FileType.image : FileType.custom,
      allowedExtensions: isImage ? null : ['pdf'],
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      String filename = result.files.single.name;
      _showTagSelectionDialog(isImage ? "IMAGE" : "PDF", file: file, content: filename);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentIcon(Icons.image, Colors.blue, "Image", () { Navigator.pop(ctx); _pickFile(true); }),
              _buildAttachmentIcon(Icons.picture_as_pdf, Colors.red, "Document", () { Navigator.pop(ctx); _pickFile(false); }),
              _buildAttachmentIcon(Icons.poll, Colors.green, "Poll", () { Navigator.pop(ctx); _showPollCreationDialog(); }),
            ]
          ),
        )
      )
    );
  }

  Widget _buildAttachmentIcon(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _react(int msgId, String emoji) async {
    await ApiService.reactToAnnouncement(msgId, emoji);
    _fetchMessages(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Only Admins can send messages", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          // --- NEW: Toggle Filter Bar Button ---
          IconButton(
            icon: Icon(_isFilterVisible ? Icons.filter_alt_off : Icons.filter_alt),
            tooltip: "Filter by Tag",
            onPressed: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
                if (!_isFilterVisible) {
                  _selectedTagFilter = null; // Reset filter if closing
                  _applyFilter();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- NEW: The Filter Bar UI ---
          if (_isFilterVisible && _availableTags.isNotEmpty)
            Container(
              height: 54,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 2))],
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: const Text("All"),
                      selected: _selectedTagFilter == null,
                      selectedColor: Colors.teal.shade100,
                      onSelected: (val) {
                        setState(() {
                          _selectedTagFilter = null;
                          _applyFilter();
                        });
                      },
                    ),
                  ),
                  ..._availableTags.map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text("#$tag"),
                      selected: _selectedTagFilter == tag,
                      selectedColor: Colors.teal.shade100,
                      onSelected: (val) {
                        setState(() {
                          _selectedTagFilter = val ? tag : null;
                          _applyFilter();
                        });
                      },
                    ),
                  )).toList(),
                ],
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : _displayedMessages.isEmpty
                    ? Center(child: Text(
                        _selectedTagFilter != null ? "No messages found for #$_selectedTagFilter" : "No announcements yet.", 
                        style: TextStyle(color: Colors.grey.shade600)
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _displayedMessages.length,
                        itemBuilder: (ctx, i) {
                          return _buildMessageBubble(_displayedMessages[i]);
                        },
                      ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map msg) {
    Widget contentWidget;
    
    if (msg['type'] == 'IMAGE' && msg['file_url'] != null) {
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network('${AppConfig.baseUrl}${msg['file_url']}', fit: BoxFit.cover),
          ),
        ]
      );
    } else if (msg['type'] == 'PDF' && msg['file_url'] != null) {
      contentWidget = Container(
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
          title: Text(msg['content'] ?? 'Document.pdf', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          trailing: IconButton(
            icon: const Icon(Icons.download, color: Colors.teal),
            onPressed: () => launchUrl(Uri.parse('${AppConfig.baseUrl}${msg['file_url']}')),
          )
        ),
      );
    } else if (msg['type'] == 'POLL') {
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("📊 ${msg['content']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...(msg['poll_options'] as List? ?? []).map((opt) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.shade200)),
            child: Text(opt['text'] ?? '', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w500)),
          )).toList()
        ]
      );
    } else {
      contentWidget = Text(msg['content'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(topLeft: Radius.zero),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6, runSpacing: 6,
              children: (msg['tags'] as List).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                child: Text("#$t", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
              )).toList(),
            ),
            const SizedBox(height: 10),
            
            contentWidget,
            
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _react(msg['id'], "👍"),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: Row(
                      children: [
                        const Text("👍", style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text("${(msg['reactions']?['👍'] ?? 0)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, HH:mm').format(DateTime.parse(msg['created_at']).toLocal()),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!widget.isAdmin) {
      return Container(
        padding: const EdgeInsets.all(16), color: Colors.white, alignment: Alignment.center,
        child: Text("Only admins can send messages", style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))]),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add, color: Colors.teal.shade700, size: 28),
              onPressed: _showAttachmentOptions, 
            ),
            Expanded(
              child: TextField(
                controller: _msgController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: "Type an announcement...",
                  fillColor: Colors.grey.shade100, filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.teal.shade700, radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () {
                  if (_msgController.text.trim().isNotEmpty) {
                    _showTagSelectionDialog("TEXT", content: _msgController.text.trim());
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}