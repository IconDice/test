class MedicalEntry {
  final String requestId;
  final String studentRollNo;
  final DateTime fromDate;
  final DateTime toDate;
  final String status;
  final String? hodRemark;
  final String reason;
  final String? documentPath;
  final String? ocrStatus;
  final String? ocrText;

  MedicalEntry({
    required this.requestId,
    required this.studentRollNo,
    required this.fromDate,
    required this.toDate,
    required this.status,
    this.hodRemark,
    required this.reason,
    this.documentPath,
    this.ocrStatus,
    this.ocrText,
  });
}
