import os
import uuid
import pytesseract
from pdf2image import convert_from_path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, BackgroundTasks
from sqlmodel import Session, select
from datetime import date
from typing import List, Optional

from database import get_db
from config import UPLOAD_DIR

# IMPORTANT: Import the model from models.py, do NOT redefine it here
from medical.models import MedicalRequest, MedicalStatus 

# --- Helpers ---
def process_ocr_background(file_path: str, request_id: str):
    try:
        images = convert_from_path(file_path)
        text = ""
        for img in images:
            text += pytesseract.image_to_string(img)
        print(f"OCR Processed for {request_id}. Text length: {len(text)}")
        # In a real app, you would save this text to the DB here
    except Exception as e:
        print(f"OCR Failed: {e}")

# --- Router ---
router = APIRouter(tags=["Medical"])

@router.post("/submit")
async def submit_medical(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    from_date: date = Form(...),
    to_date: date = Form(...),
    reason: str = Form(...),
    student_roll_no: str = Form(...),
    department_id: str = Form(...),
    db: Session = Depends(get_db)
):
    # 1. Save File
    filename = f"{uuid.uuid4()}.pdf"
    file_path = os.path.join(UPLOAD_DIR, filename)

    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)

    # 2. Create Database Entry using the imported MedicalRequest model
    req = MedicalRequest(
        student_roll_no=student_roll_no,
        department_id=department_id,
        from_date=from_date,
        to_date=to_date,
        reason=reason,
        document_path=file_path,
        status=MedicalStatus.PENDING # Use the imported Enum
    )
    db.add(req)
    db.commit()
    db.refresh(req)

    # 3. Trigger Background OCR
    background_tasks.add_task(process_ocr_background, file_path, str(req.id))

    return {"success": True, "request_id": str(req.id), "status": "PENDING"}

@router.get("/hod/pending")
def get_pending(department_id: str, db: Session = Depends(get_db)):
    # Fetch requests where status is PENDING and department matches
    reqs = db.exec(
        select(MedicalRequest)
        .where(MedicalRequest.department_id == department_id)
        .where(MedicalRequest.status == MedicalStatus.PENDING)
    ).all()
    
    # Map to JSON response
    return [
        {
            "request_id": str(r.id),
            "student_roll_no": r.student_roll_no,
            "from_date": r.from_date,
            "to_date": r.to_date,
            "status": r.status,
            "hod_remark": r.hod_remark
        }
        for r in reqs
    ]

@router.post("/hod/review")
def review_medical(
    payload: dict, 
    db: Session = Depends(get_db)
):
    req_id = payload.get("request_id")
    action = payload.get("action")
    remark = payload.get("remark")

    # Fetch the request
    req = db.get(MedicalRequest, uuid.UUID(req_id))
    if not req: 
        raise HTTPException(404, "Not Found")

    # Update status
    req.status = action
    req.hod_remark = remark
    db.add(req)
    db.commit()
    
    return {"success": True}