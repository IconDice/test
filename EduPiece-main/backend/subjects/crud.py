from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from .models import Subject

def create_subject(db: Session, data):
    subject = Subject(**data.dict())
    try:
        db.add(subject)
        db.commit()
        db.refresh(subject)
        return subject
    except IntegrityError:
        db.rollback()
        raise ValueError("Subject code already exists")

def get_subjects(db: Session, skip: int = 0, limit: int = 20):
    statement = select(Subject).offset(skip).limit(limit)
    return db.exec(statement).all()

def delete_subject(db: Session, subject_id: str):
    subject = db.get(Subject, subject_id)
    if not subject:
        return None
    db.delete(subject)
    db.commit()
    return subject