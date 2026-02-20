from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlmodel import Session, select
from database import get_db
from auth.models import User
from core.dependencies import get_current_user
from .models import *
from .schemas import *
import random, string, shutil, os
from config import UPLOAD_DIR

router = APIRouter()

def generate_join_code(length=6):
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=length))

def save_file(file: UploadFile, subfolder: str) -> str:
    folder = os.path.join(UPLOAD_DIR, "classroom", subfolder)
    os.makedirs(folder, exist_ok=True)
    file_path = os.path.join(folder, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return f"/uploads/classroom/{subfolder}/{file.filename}"

# --- Classroom Management ---

@router.post("/create", response_model=ClassroomRead)
def create_classroom(
    class_data: ClassroomCreate, 
    user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    if user.role != "TEACHER":
        raise HTTPException(403, "Only teachers can create classrooms")
    
    code = generate_join_code()
    new_class = Classroom(name=class_data.name, teacher_id=user.id, join_code=code)
    db.add(new_class)
    db.commit()
    db.refresh(new_class)
    return ClassroomRead(**new_class.dict(), is_teacher=True)

@router.post("/join")
def join_classroom(
    join_data: JoinClassroom, 
    user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    classroom = db.exec(select(Classroom).where(Classroom.join_code == join_data.code)).first()
    if not classroom:
        raise HTTPException(404, "Invalid Class Code")
    
    existing = db.exec(select(ClassroomMember).where(
        ClassroomMember.classroom_id == classroom.id,
        ClassroomMember.student_id == user.id
    )).first()
    
    if existing:
        return {"message": "Already joined"}
        
    member = ClassroomMember(classroom_id=classroom.id, student_id=user.id)
    db.add(member)
    db.commit()
    return {"message": f"Successfully joined {classroom.name}"}

@router.get("/my-classes", response_model=List[ClassroomRead])
def get_my_classes(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if user.role == "TEACHER":
        classes = db.exec(select(Classroom).where(Classroom.teacher_id == user.id)).all()
        return [ClassroomRead(**c.dict(), is_teacher=True) for c in classes]
    else:
        statement = select(Classroom).join(ClassroomMember).where(ClassroomMember.student_id == user.id)
        classes = db.exec(statement).all()
        return [ClassroomRead(**c.dict(), is_teacher=False) for c in classes]

# --- Notes ---

@router.post("/{class_id}/notes", response_model=NoteRead)
def upload_note(
    class_id: int,
    title: str = Form(...),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if user.role != "TEACHER":
        raise HTTPException(403, "Only teachers upload notes")
    
    url = save_file(file, "notes")
    note = Note(classroom_id=class_id, title=title, file_url=url)
    db.add(note)
    db.commit()
    db.refresh(note)
    return note

@router.get("/{class_id}/notes", response_model=List[NoteRead])
def get_notes(class_id: int, db: Session = Depends(get_db)):
    return db.exec(select(Note).where(Note.classroom_id == class_id)).all()

# --- Assignments ---

@router.post("/{class_id}/assignments", response_model=AssignmentRead)
def create_assignment(
    class_id: int,
    title: str = Form(...),
    deadline: datetime = Form(...),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if user.role != "TEACHER": raise HTTPException(403, "Unauthorized")
    url = save_file(file, "assignments")
    assign = Assignment(classroom_id=class_id, title=title, deadline=deadline, file_url=url)
    db.add(assign)
    db.commit()
    db.refresh(assign)
    return assign

@router.get("/{class_id}/assignments", response_model=List[AssignmentRead])
def list_assignments(class_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    assignments = db.exec(select(Assignment).where(Assignment.classroom_id == class_id)).all()
    result = []
    for a in assignments:
        is_sub = False
        if user.role == "STUDENT":
            sub = db.exec(select(AssignmentSubmission).where(
                AssignmentSubmission.assignment_id == a.id,
                AssignmentSubmission.student_id == user.id
            )).first()
            if sub: is_sub = True
        result.append(AssignmentRead(**a.dict(), is_submitted=is_sub))
    return result

@router.post("/assignments/{assign_id}/submit")
def submit_assignment(
    assign_id: int,
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    assign = db.get(Assignment, assign_id)
    if not assign: raise HTTPException(404, "Assignment not found")
    
    # --- STRICT DEADLINE ENFORCEMENT ---
    if datetime.utcnow() > assign.deadline:
        raise HTTPException(status_code=400, detail="Deadline has passed. Submissions are closed.")
    
    # --- PREVENT DUPLICATE SUBMISSIONS ---
    existing = db.exec(select(AssignmentSubmission).where(
        AssignmentSubmission.assignment_id == assign_id,
        AssignmentSubmission.student_id == user.id
    )).first()
    if existing:
        raise HTTPException(status_code=400, detail="You have already submitted this assignment.")
        
    url = save_file(file, "submissions")
    sub = AssignmentSubmission(assignment_id=assign_id, student_id=user.id, file_url=url)
    db.add(sub)
    db.commit()
    return {"message": "Submitted successfully"}

# --- Tests ---

@router.post("/{class_id}/tests")
def create_test(
    class_id: int,
    test_data: TestCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if user.role != "TEACHER": raise HTTPException(403, "Unauthorized")
    
    if test_data.start_time >= test_data.end_time:
        raise HTTPException(400, "End time must be after start time.")

    test = Test(
        classroom_id=class_id, title=test_data.title, 
        start_time=test_data.start_time, end_time=test_data.end_time
    )
    db.add(test)
    db.commit()
    db.refresh(test)
    
    for q in test_data.questions:
        que = TestQuestion(
            test_id=test.id, question_text=q.question_text, 
            options=q.options, correct_option_index=q.correct_option_index
        )
        db.add(que)
    db.commit()
    return {"message": "Test created"}

@router.get("/{class_id}/tests", response_model=List[TestRead])
def list_tests(class_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    tests = db.exec(select(Test).where(Test.classroom_id == class_id)).all()
    return tests

@router.get("/tests/{test_id}/questions", response_model=List[TestQuestionRead])
def get_test_questions(test_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    test = db.get(Test, test_id)
    if not test: raise HTTPException(404, "Test not found")
    
    # Prevent students from viewing questions before the start time
    if user.role == "STUDENT" and datetime.utcnow() < test.start_time:
         raise HTTPException(400, "Test has not started yet")
         
    questions = db.exec(select(TestQuestion).where(TestQuestion.test_id == test_id)).all()
    return questions

@router.post("/tests/submit")
def submit_test(
    submission: TestSubmit,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    test = db.get(Test, submission.test_id)
    if not test: raise HTTPException(404, "Test not found")
    
    # --- STRICT TIMING ENFORCEMENT ---
    if datetime.utcnow() > test.end_time:
        raise HTTPException(status_code=400, detail="Test time has ended.")
    if datetime.utcnow() < test.start_time:
        raise HTTPException(status_code=400, detail="Test hasn't started yet.")
        
    # --- PREVENT DUPLICATE SUBMISSIONS ---
    existing = db.exec(select(TestSubmission).where(
        TestSubmission.test_id == test.id,
        TestSubmission.student_id == user.id
    )).first()
    if existing:
        raise HTTPException(status_code=400, detail="You have already taken this test.")
    
    questions = db.exec(select(TestQuestion).where(TestQuestion.test_id == submission.test_id)).all()
    
    score = 0
    for i, q in enumerate(questions):
        if i < len(submission.answers) and submission.answers[i] == q.correct_option_index:
            score += 1
            
    result = TestSubmission(
        test_id=test.id, student_id=user.id, 
        score=score, total_questions=len(questions),
        answers=submission.answers
    )
    db.add(result)
    db.commit()
    return {"score": score, "total": len(questions)}

# --- Analytics ---

@router.get("/assignments/{assign_id}/submissions")
def get_assignment_submissions(
    assign_id: int, 
    user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    if user.role != "TEACHER": raise HTTPException(403, "Unauthorized")
    
    results = db.exec(
        select(AssignmentSubmission, User.full_name)
        .join(User, AssignmentSubmission.student_id == User.id)
        .where(AssignmentSubmission.assignment_id == assign_id)
    ).all()
    
    return [
        {
            "student_name": r[1],
            "submitted_at": r[0].submitted_at,
            "file_url": r[0].file_url
        } 
        for r in results
    ]

@router.get("/tests/{test_id}/results")
def get_test_results(
    test_id: int, 
    user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    if user.role != "TEACHER": raise HTTPException(403, "Unauthorized")
    
    results = db.exec(
        select(TestSubmission, User.full_name)
        .join(User, TestSubmission.student_id == User.id)
        .where(TestSubmission.test_id == test_id)
    ).all()
    
    return [
        {
            "student_name": r[1],
            "score": r[0].score,
            "total": r[0].total_questions,
            "submitted_at": r[0].submitted_at
        } 
        for r in results
    ]