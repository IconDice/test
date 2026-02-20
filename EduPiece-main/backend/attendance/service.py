from datetime import timedelta
from sqlmodel import Session, select
from attendance.models import AttendanceStatus, AttendanceAuditLog, AttendanceRecord, AttendanceSession
from students.models import Student

def apply_medical_leave(db: Session, student_roll_no: str, from_date, to_date):
    # 1. Get Student
    student = db.exec(select(Student).where(Student.roll_no == student_roll_no)).first()
    if not student:
        return

    # 2. Iterate dates
    delta = (to_date - from_date).days + 1
    
    for i in range(delta):
        current_date = from_date + timedelta(days=i)
        
        # 3. Find records for this student on this date
        # Joins AttendanceRecord to AttendanceSession to filter by date
        statement = (
            select(AttendanceRecord)
            .join(AttendanceSession)
            .where(AttendanceRecord.student_id == student.id)
            .where(AttendanceSession.session_date == current_date)
        )
        records = db.exec(statement).all()
        
        for record in records:
            # SAFETY CHECK: Only change ABSENT to MEDICAL_LEAVE
            if record.status == AttendanceStatus.ABSENT:
                old_status = record.status
                record.status = AttendanceStatus.MEDICAL_LEAVE
                
                # Audit Log
                db.add(AttendanceAuditLog(
                    student_roll_no=student_roll_no,
                    date=current_date,
                    subject_id=str(record.session.subject_id),
                    old_status=old_status,
                    new_status=AttendanceStatus.MEDICAL_LEAVE,
                    updated_by="SYSTEM_MEDICAL_OCR"
                ))

    db.commit()