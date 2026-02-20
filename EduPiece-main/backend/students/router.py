from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
import uuid

from database import get_db
from core.dependencies import require_role
from . import schemas, crud

router = APIRouter(prefix="/api/admin/students", tags=["Admin - Students"])

@router.post("/", response_model=schemas.StudentResponse)
def create_student(
    payload: schemas.StudentCreate,
    db: Session = Depends(get_db),
    user=Depends(require_role(["ADMIN"])), # Fixed: list format
):
    try:
        return crud.create_student(db, payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/", response_model=list[schemas.StudentResponse])
def list_students(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    user=Depends(require_role(["ADMIN"])), # Fixed: list format
):
    return crud.get_students(db, skip, limit)

@router.delete("/{student_id}")
def delete_student(
    student_id: uuid.UUID,
    db: Session = Depends(get_db),
    user=Depends(require_role(["ADMIN"])), # Fixed: list format
):
    student = crud.delete_student(db, str(student_id))
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    return {"success": True}