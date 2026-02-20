from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from .models import Student

def create_student(db: Session, data):
    student = Student(**data.dict())
    try:
        db.add(student)
        db.commit()
        db.refresh(student)
        return student
    except IntegrityError:
        db.rollback()
        raise ValueError("Roll number already exists")

def get_students(db: Session, skip: int = 0, limit: int = 20):
    statement = select(Student).offset(skip).limit(limit)
    return db.exec(statement).all()

def delete_student(db: Session, student_id: str):
    student = db.get(Student, student_id)
    if not student:
        return None
    db.delete(student)
    db.commit()
    return student