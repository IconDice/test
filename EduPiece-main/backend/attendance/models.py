from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import date, datetime
import uuid as uuid_pkg
from enum import Enum

# --- ENUMS ---
class AttendanceStatus(str, Enum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    MEDICAL_LEAVE = "MEDICAL_LEAVE"

class DayOfWeek(str, Enum):
    MONDAY = "MONDAY"
    TUESDAY = "TUESDAY"
    WEDNESDAY = "WEDNESDAY"
    THURSDAY = "THURSDAY"
    FRIDAY = "FRIDAY"
    SATURDAY = "SATURDAY"

# --- NEW MODEL: Class Schedule (TimeTable) ---
class ClassSchedule(SQLModel, table=True):
    __tablename__ = "class_schedules"

    id: uuid_pkg.UUID = Field(default_factory=uuid_pkg.uuid4, primary_key=True)
    subject_id: uuid_pkg.UUID = Field(foreign_key="subjects.id", index=True)
    faculty_id: uuid_pkg.UUID = Field(foreign_key="users.id", index=True)
    day_of_week: DayOfWeek
    start_time: str # Format "HH:MM" (e.g., "10:30")
    end_time: str   # Format "HH:MM"
    room_number: str = Field(default="LAB-1")

    # We don't need extensive relationships for this demo, keeping it lightweight
    # to avoid circular imports with Subject/User models

# --- EXISTING MODELS (Unchanged) ---
class AttendanceSession(SQLModel, table=True):
    __tablename__ = "attendance_sessions"
    id: uuid_pkg.UUID = Field(default_factory=uuid_pkg.uuid4, primary_key=True)
    subject_id: str = Field(index=True) 
    faculty_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    session_date: date = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    records: List["AttendanceRecord"] = Relationship(back_populates="session")

class AttendanceRecord(SQLModel, table=True):
    __tablename__ = "attendance_records"
    id: uuid_pkg.UUID = Field(default_factory=uuid_pkg.uuid4, primary_key=True)
    session_id: uuid_pkg.UUID = Field(foreign_key="attendance_sessions.id")
    student_roll_no: str = Field(index=True) 
    status: AttendanceStatus = Field(default=AttendanceStatus.ABSENT)
    session: AttendanceSession = Relationship(back_populates="records")

class AttendanceAuditLog(SQLModel, table=True):
    __tablename__ = "attendance_audit_logs"
    id: uuid_pkg.UUID = Field(default_factory=uuid_pkg.uuid4, primary_key=True)
    student_roll_no: str
    date: date
    subject_id: str
    old_status: Optional[str] = None
    new_status: str
    updated_by: str = "SYSTEM"
    source: str = "MEDICAL_APPROVAL"
    timestamp: datetime = Field(default_factory=datetime.utcnow)