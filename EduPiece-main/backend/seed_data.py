import random
from sqlmodel import Session, text, select
from database import engine
from auth.models import User
from students.models import Student
from subjects.models import Subject
from attendance.models import ClassSchedule, DayOfWeek
from core.security import get_password_hash
from sqlmodel import SQLModel
from announcements import models as announce_models

def wipe_database():
    print("🗑️  Wiping existing tables...")
    try:
        SQLModel.metadata.drop_all(engine)
    except Exception as e:
        print(f"⚠️ Drop failed (might be first run): {e}")
    
    print("✨ Creating new tables...")
    SQLModel.metadata.create_all(engine)

def seed_data():
    with Session(engine) as session:
        print("🌱 Seeding Departmental Data...")

        # --- 1. Create HoD ---
        hod_password = get_password_hash("hod@123")
        hod = User(
            username="hod_cse_001", 
            full_name="Prof. Dr. Srinivas Sethi", 
            password_hash=hod_password, 
            role="HOD"
        )
        session.add(hod)

        # --- 2. Create Teachers ---
        print("👨‍🏫 Creating Faculty Members...")
        teacher_names = [
            "Prof. Dr. Niroj Pani", "Prof. Dr. Suvendu Rout", "Prof. Dr. Sangita Pal",
            "Prof. Dr. Susmita Mishra", "Prof. Dr. Sushant Sahoo", 
            "Prof. Dr. Biswanath Sethi", "Prof. Dr. M. Srinivas"
        ]
        
        created_teachers = []
        for i, name in enumerate(teacher_names):
            t_id = f"TCH-{100 + i}"
            t_user = User(
                username=t_id, full_name=name, 
                password_hash=get_password_hash(f"pass@{100+i}"), 
                role="TEACHER"
            )
            session.add(t_user)
            created_teachers.append(t_user)
        session.commit()
        for t in created_teachers: session.refresh(t)

        # --- 3. Create Subjects ---
        print("📚 Creating Subjects...")
        # All subjects set to Sem 6 for this demo so all students appear
        # or we ensure the teacher we login as has a Sem 6 subject.
        subject_config = [
            ("CS601", "Machine Learning", 6),
            ("CS602", "Compiler Design", 6),
            ("CS603", "Computer Networks", 6),
            ("CS604", "Cloud Computing", 6),
            ("CS605", "Data Structures", 6), # Moved to 6 for demo unity
            ("CS606", "Operating Systems", 6)
        ]

        created_subjects = []
        for idx, (code, name, sem) in enumerate(subject_config):
            assigned_faculty = created_teachers[idx % len(created_teachers)]
            subj = Subject(
                code=code, name=name, department_id="CSE", semester=sem,
                faculty_id=assigned_faculty.id
            )
            session.add(subj)
            created_subjects.append((subj, assigned_faculty))
        session.commit()
        for s, f in created_subjects: session.refresh(s)

        # --- 4. Create Schedules ---
        print("📅 Creating Schedules...")
        days_pool = [DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY]
        for subj, faculty in created_subjects:
            selected_days = random.sample(days_pool, 3)
            for day in selected_days:
                start_hour = random.randint(9, 15)
                sched = ClassSchedule(
                    subject_id=subj.id, faculty_id=faculty.id, day_of_week=day,
                    start_time=f"{start_hour:02d}:00", end_time=f"{start_hour+1:02d}:00",
                    room_number=f"LH-{random.randint(101, 105)}"
                )
                session.add(sched)
        session.commit()

        # --- 5. Create 50 Students (ALL IN SEMESTER 6) ---
        print("🎓 Creating 50 Students (All Sem 6)...")
        reg_start = 2301105217
        pass_start = 427001
        
        for i in range(50):
            reg_no = str(reg_start + i)
            s_user = User(
                username=reg_no, full_name=f"Student {i+1}", 
                password_hash=get_password_hash(str(pass_start + i)), 
                role="STUDENT"
            )
            session.add(s_user)
            session.flush() 
            session.refresh(s_user)

            # !!! FIX: ALL STUDENTS ARE NOW SEMESTER 6 !!!
            s_profile = Student(
                user_id=s_user.id, roll_no=reg_no, name=s_user.full_name,
                department_id="CSE", semester=6 
            )
            session.add(s_profile)
        
        session.commit()
        print("✅ Seeding Complete! All 50 students are now in Semester 6.")

if __name__ == "__main__":
    wipe_database()
    seed_data()