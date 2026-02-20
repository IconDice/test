from sqlmodel import SQLModel, text
from database import engine
# Import your models so SQLModel knows what to recreate
from auth.models import User
from students.models import Student
from subjects.models import Subject
from attendance.models import AttendanceSession, AttendanceRecord, AttendanceAuditLog
from medical.models import MedicalRequest, MedicalProcessingJob
from announcements import models as announce_models

def reset_database():
    print("⚠️  Warning: This will delete ALL data and ALL tables.")
    confirm = input("Are you sure you want to proceed? (y/n): ")
    
    if confirm.lower() == 'y':
        print("Forcing a complete database wipe...")
        with engine.begin() as connection:
            # Use raw SQL to drop the entire public schema and recreate it
            # This effectively wipes every table, even those not imported here.
            connection.execute(text("DROP SCHEMA public CASCADE;"))
            connection.execute(text("CREATE SCHEMA public;"))
            connection.execute(text("GRANT ALL ON SCHEMA public TO postgres;"))
            connection.execute(text("GRANT ALL ON SCHEMA public TO public;"))
            
        print("Recreating clean tables...")
        SQLModel.metadata.create_all(engine)
        print("✅ Database is now completely fresh.")
    else:
        print("Operation cancelled.")

if __name__ == "__main__":
    reset_database()