from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import uuid

# --- Classroom ---
class ClassroomCreate(BaseModel):
    name: str

class ClassroomRead(BaseModel):
    id: int
    name: str
    join_code: str
    teacher_id: uuid.UUID
    is_teacher: bool = False

# --- Join ---
class JoinClassroom(BaseModel):
    code: str

# --- Notes ---
class NoteRead(BaseModel):
    id: int
    title: str
    file_url: str
    created_at: datetime

# --- Assignments ---
class AssignmentCreate(BaseModel):
    title: str
    deadline: datetime

class AssignmentRead(BaseModel):
    id: int
    title: str
    file_url: str
    deadline: datetime
    is_submitted: bool = False

# --- Tests ---
class QuestionCreate(BaseModel):
    question_text: str
    options: List[str]
    correct_option_index: int

class TestCreate(BaseModel):
    title: str
    start_time: datetime
    end_time: datetime
    questions: List[QuestionCreate]

class TestRead(BaseModel):
    id: int
    title: str
    start_time: datetime
    end_time: datetime
    is_attempted: bool = False

class TestQuestionRead(BaseModel):
    id: int
    question_text: str
    options: List[str]

class TestSubmit(BaseModel):
    test_id: int
    answers: List[int]