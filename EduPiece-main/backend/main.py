from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import SQLModel
from database import engine
from config import UPLOAD_DIR
import os

# --- IMPORTANT: Import ALL Models here so SQLModel finds them ---
from auth.models import User
from attendance.models import AttendanceSession, AttendanceRecord, AttendanceAuditLog
from medical.models import MedicalRequest, MedicalProcessingJob
from students.models import Student
from subjects.models import Subject
from classroom import models as classroom_models 
from classroom.router import router as classroom_router

# NEW: Import Announcement Models
from announcements import models as announce_models 

# --- Import Routers ---
from auth.router import router as auth_router
from attendance.router import router as attendance_router
from medical.router import router as medical_router
from students.router import router as student_router
from subjects.router import router as subject_router
from evaluation.router import router as eval_router

# NEW: Import Announcement Router
from announcements.router import router as announce_router 

app = FastAPI(title="EduFlow Merged API")

# --- Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Static Files ---
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# --- Routes ---
app.include_router(auth_router, prefix="/api/auth")
app.include_router(attendance_router, prefix="/api/attendance")
app.include_router(medical_router, prefix="/api/medical")
app.include_router(student_router, prefix="/api/students")
app.include_router(subject_router, prefix="/api/subjects")
app.include_router(eval_router, prefix="/api/evaluation")
app.include_router(classroom_router, prefix="/api/classroom", tags=["Classroom"])

# NEW: Include Announcement Routes
app.include_router(announce_router, prefix="/api/announce", tags=["Announcements"]) 

@app.on_event("startup")
def on_startup():
    # This creates the tables in the database
    SQLModel.metadata.create_all(engine)
    os.makedirs(UPLOAD_DIR, exist_ok=True)