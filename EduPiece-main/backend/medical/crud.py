import uuid as uuid_pkg
from sqlmodel import Session, select
from medical.models import MedicalRequest, MedicalStatus
from datetime import datetime

def create_medical_request(db: Session, **data):
    request = MedicalRequest(**data)
    db.add(request)
    db.commit()
    db.refresh(request)
    return request

def review_request(db: Session, request_id: uuid_pkg.UUID, action: MedicalStatus, remark: str):
    request = db.get(MedicalRequest, request_id)
    if not request: return None
    
    request.status = action
    request.hod_remark = remark
    db.add(request)
    db.commit()
    db.refresh(request)
    return request

def get_pending_requests_for_hod(db: Session, department_id: str):
    statement = select(MedicalRequest).where(
        MedicalRequest.department_id == department_id,
        MedicalRequest.status == MedicalStatus.PENDING
    )
    return db.exec(statement).all()