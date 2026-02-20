from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select, func
from typing import List
from datetime import date
from pydantic import BaseModel
import uuid

from database import get_db
from attendance.models import AttendanceSession, AttendanceRecord, AttendanceStatus, ClassSchedule
from auth.models import User
from students.models import Student
from subjects.models import Subject

# --- Schemas ---
class AttendanceItem(BaseModel):
    roll_no: str
    status: str

class AttendanceSubmitRequest(BaseModel):
    subject_id: str
    date: date
    records: List[AttendanceItem]

class RollListRequest(BaseModel):
    class_id: str
    subject_id: str

class ScheduleItem(BaseModel):
    subject_name: str
    subject_code: str
    time_slot: str
    room: str
    class_identifier: str 

# --- Router ---
router = APIRouter(tags=["Attendance"])

@router.get("/teacher/schedule/{faculty_id}", response_model=List[ScheduleItem])
def get_teacher_schedule(faculty_id: str, db: Session = Depends(get_db)):
    """
    Fetches the weekly schedule for a specific teacher.
    """
    try:
        # Convert string ID to UUID if necessary, or assume string if that's how DB is set
        # For our seed data, IDs are UUIDs.
        
        # Join Schedule -> Subject
        statement = (
            select(ClassSchedule, Subject)
            .join(Subject, ClassSchedule.subject_id == Subject.id)
            .where(ClassSchedule.faculty_id == uuid.UUID(faculty_id))
        )
        results = db.exec(statement).all()
        
        schedule_list = []
        for sched, subj in results:
            schedule_list.append(ScheduleItem(
                subject_name=subj.name,
                subject_code=subj.code,
                time_slot=f"{sched.start_time} - {sched.end_time}",
                room=sched.room_number,
                class_identifier=f"{subj.department_id} - {subj.semester}th Sem"
            ))
        
        return schedule_list
    except Exception as e:
        print(f"Error fetching schedule: {e}")
        return []

@router.post("/roll-list")
def fetch_roll_list(payload: RollListRequest, db: Session = Depends(get_db)):
    """
    Fetches the list of students for a given subject.
    Includes a fallback mechanism to ensure the list is never empty for demos.
    """
    print(f"Fetching rolls for Subject: {payload.subject_id}")
    
    # 1. Try to find the Subject to know its Semester
    subject = db.exec(select(Subject).where(Subject.code == payload.subject_id)).first()
    
    students = []
    
    if subject:
        # 2. Attempt: Smart Filter (Students in that Semester)
        students = db.exec(
            select(Student)
            .where(Student.department_id == subject.department_id)
            .where(Student.semester == subject.semester)
            .order_by(Student.roll_no)
        ).all()
        print(f"Smart Filter found {len(students)} students for Sem {subject.semester}")

    # 3. Fallback: If Smart Filter returned 0 (or subject not found), fetch ALL students
    if not students:
        print("⚠️ Smart Filter empty. Falling back to ALL students.")
        students = db.exec(select(Student).order_by(Student.roll_no)).all()
        
    # 4. Final Safety: If Student table is empty, look at Users table
    if not students:
        print("⚠️ Student table empty. Falling back to User table.")
        users = db.exec(select(User).where(User.role == "STUDENT")).all()
        # Mock student objects from users
        roll_numbers = [u.username for u in users]
    else:
        roll_numbers = [s.roll_no for s in students]

    return {
        "date": date.today(), 
        "roll_numbers": roll_numbers,
        "count": len(roll_numbers)
    }

@router.post("/submit")
def submit_attendance(
    payload: AttendanceSubmitRequest, 
    db: Session = Depends(get_db)
):
    # 1. Find the Subject ID (UUID) from the Code string
    subject = db.exec(select(Subject).where(Subject.code == payload.subject_id)).first()
    
    if not subject:
        # If subject not found in DB, we can't link it properly.
        # For resilience, we might create a dummy session or raise error.
        raise HTTPException(status_code=404, detail="Subject not found")

    # 2. Create Session
    session = AttendanceSession(
        subject_id=payload.subject_id, # Storing the Code (e.g. CS601) for display
        session_date=payload.date,
        faculty_id=subject.faculty_id 
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # 3. Add Records
    for rec in payload.records:
        record = AttendanceRecord(
            session_id=session.id,
            student_roll_no=rec.roll_no,
            status=rec.status
        )
        db.add(record)
    
    db.commit()
    return {"success": True, "message": "Attendance Saved"}

@router.get("/student/stats/{student_id}")
def get_student_stats(student_id: str, db: Session = Depends(get_db)):
    # Total classes (Count records for this student)
    total = db.exec(
        select(func.count(AttendanceRecord.id))
        .where(AttendanceRecord.student_roll_no == student_id)
    ).one()

    # Present count
    present = db.exec(
        select(func.count(AttendanceRecord.id))
        .where(AttendanceRecord.student_roll_no == student_id)
        .where(AttendanceRecord.status == AttendanceStatus.PRESENT)
    ).one()

    percentage = round((present / total * 100), 1) if total > 0 else 0.0

    return {
        "percentage": percentage,
        "total_classes": total,
        "present_count": present,
        "absent_count": total - present,
        "is_shortage": percentage < 75.0
    }