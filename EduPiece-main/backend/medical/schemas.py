from datetime import date
from typing import Optional
from pydantic import BaseModel
from enum import Enum

class MedicalStatus(str, Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"

class MedicalSubmitResponse(BaseModel):
    success: bool
    request_id: str
    status: MedicalStatus

class HoDReviewRequest(BaseModel):
    request_id: str
    action: MedicalStatus
    remark: Optional[str] = None

class MedicalListItem(BaseModel):
    request_id: str
    student_roll_no: str
    from_date: date
    to_date: date
    status: MedicalStatus
    hod_remark: Optional[str]
