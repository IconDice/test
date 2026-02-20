import uuid as uuid_pkg
from datetime import date
from sqlmodel import Session, select, func
from attendance.models import AttendanceSession, AttendanceRecord
from students.models import Student
from subjects.models import Subject

def create_attendance_session(db: Session, subject_code: str, session_date: date, faculty_id: uuid_pkg.UUID, records: list):
    # 1. Get Subject
    subject = db.exec(select(Subject).where(Subject.code == subject_code)).first()
    if not subject: raise ValueError("Subject not found")

    # 2. Create Session
    session = AttendanceSession(subject_id=subject.id, faculty_id=faculty_id, session_date=session_date)
    db.add(session)
    db.flush()

    # 3. Bulk Fetch Students to avoid N+1 queries
    roll_numbers = [r.roll_no for r in records]
    students = db.exec(select(Student).where(Student.roll_no.in_(roll_numbers))).all()
    student_map = {s.roll_no: s.id for s in students}

    # 4. Create Records
    attendance_objs = []
    for r in records:
        if r.roll_no in student_map:
            attendance_objs.append(AttendanceRecord(
                session_id=session.id, 
                student_id=student_map[r.roll_no], 
                status=r.status
            ))
    
    db.add_all(attendance_objs)
    db.commit()
    db.refresh(session)
    return session