class AttendanceEntry {
  final String rollNo;
  String? status;

  AttendanceEntry({required this.rollNo, this.status});

  // Maps to Project B's expected backend schema
  Map<String, dynamic> toJson() {
    return {
      'roll_no': rollNo,
      'status': status ?? 'ABSENT',
    };
  }
}
