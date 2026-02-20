class Classroom {
  final int id;
  final String name;
  final String joinCode;
  final bool isTeacher;

  Classroom({required this.id, required this.name, required this.joinCode, required this.isTeacher});

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: json['id'],
      name: json['name'],
      joinCode: json['join_code'] ?? '',
      isTeacher: json['is_teacher'] ?? false,
    );
  }
}

class Note {
  final int id;
  final String title;
  final String fileUrl;

  Note({required this.id, required this.title, required this.fileUrl});

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(id: json['id'], title: json['title'], fileUrl: json['file_url']);
  }
}

class Assignment {
  final int id;
  final String title;
  final String fileUrl;
  final DateTime deadline;
  final bool isSubmitted;

  Assignment({required this.id, required this.title, required this.fileUrl, required this.deadline, required this.isSubmitted});

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'],
      title: json['title'],
      fileUrl: json['file_url'],
      deadline: DateTime.parse(json['deadline']),
      isSubmitted: json['is_submitted'] ?? false,
    );
  }
}