from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
import uuid

from database import get_db
from core.dependencies import require_role
from . import schemas, crud

router = APIRouter(prefix="/api/admin/subjects", tags=["Admin - Subjects"])

@router.post("/", response_model=schemas.SubjectResponse)
def create_subject(
    payload: schemas.SubjectCreate,
    db: Session = Depends(get_db),
    user=Depends(require_role(["ADMIN"])), # Fixed: list format
):
    try:
        return crud.create_subject(db, payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/", response_model=list[schemas.SubjectResponse])
def list_subjects(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    user=Depends(require_role(["ADMIN"])), # Fixed: list format
):
    return crud.get_subjects(db, skip, limit)

@router.delete("/{subject_id}")
def delete_subject(
    subject_id: uuid.UUID,
    db: Session = Depends(get_db),
    user=Depends(require_role(["ADMIN"])), # Fixed: list format
):
    subject = crud.delete_subject(db, str(subject_id))
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    return {"success": True}