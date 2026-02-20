from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
import uuid as uuid_pkg
from sqlalchemy import JSON, Column  # <--- CRITICAL IMPORT FOR FIXING LIST ERROR
from auth.models import User

# --- Link Table for Many-to-Many (Students <-> Classrooms) ---
class ClassroomMember(SQLModel, table=True):
    __tablename__ = "classroom_members"
    id: Optional[int] = Field(default=None, primary_key=True)
    classroom_id: int = Field(foreign_key="classrooms.id")
    student_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    joined_at: datetime = Field(default_factory=datetime.utcnow)

class Classroom(SQLModel, table=True):
    __tablename__ = "classrooms"
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    teacher_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    join_code: str = Field(unique=True, index=True) # 6-char alphanumeric
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    notes: List["Note"] = Relationship(back_populates="classroom")
    assignments: List["Assignment"] = Relationship(back_populates="classroom")
    tests: List["Test"] = Relationship(back_populates="classroom")

class Note(SQLModel, table=True):
    __tablename__ = "classroom_notes"
    id: Optional[int] = Field(default=None, primary_key=True)
    classroom_id: int = Field(foreign_key="classrooms.id")
    title: str
    file_url: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    classroom: Optional[Classroom] = Relationship(back_populates="notes")

class Assignment(SQLModel, table=True):
    __tablename__ = "classroom_assignments"
    id: Optional[int] = Field(default=None, primary_key=True)
    classroom_id: int = Field(foreign_key="classrooms.id")
    title: str
    file_url: str
    deadline: datetime
    created_at: datetime = Field(default_factory=datetime.utcnow)
    classroom: Optional[Classroom] = Relationship(back_populates="assignments")

class AssignmentSubmission(SQLModel, table=True):
    __tablename__ = "classroom_assignment_submissions"
    id: Optional[int] = Field(default=None, primary_key=True)
    assignment_id: int = Field(foreign_key="classroom_assignments.id")
    student_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    file_url: str
    submitted_at: datetime = Field(default_factory=datetime.utcnow)

# --- MCQ Test Models ---
class Test(SQLModel, table=True):
    __tablename__ = "classroom_tests"
    id: Optional[int] = Field(default=None, primary_key=True)
    classroom_id: int = Field(foreign_key="classrooms.id")
    title: str
    start_time: datetime
    end_time: datetime
    created_at: datetime = Field(default_factory=datetime.utcnow)
    classroom: Optional[Classroom] = Relationship(back_populates="tests")
    questions: List["TestQuestion"] = Relationship(back_populates="test")

class TestQuestion(SQLModel, table=True):
    __tablename__ = "classroom_test_questions"
    id: Optional[int] = Field(default=None, primary_key=True)
    test_id: int = Field(foreign_key="classroom_tests.id")
    question_text: str
    # --- FIX 1: Store options list as JSON ---
    options: List[str] = Field(sa_column=Column(JSON)) 
    correct_option_index: int # 0, 1, 2, or 3
    test: Optional[Test] = Relationship(back_populates="questions")

class TestSubmission(SQLModel, table=True):
    __tablename__ = "classroom_test_submissions"
    id: Optional[int] = Field(default=None, primary_key=True)
    test_id: int = Field(foreign_key="classroom_tests.id")
    student_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    score: int
    total_questions: int
    # --- FIX 2: Store answers list as JSON ---
    answers: List[int] = Field(sa_column=Column(JSON))
    submitted_at: datetime = Field(default_factory=datetime.utcnow)