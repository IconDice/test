from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import date, datetime
import uuid as uuid_pkg
from enum import Enum

# 1. Enums for fixed status choices
class ProcessingStatus(str, Enum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"

class MedicalStatus(str, Enum):  # Fixed: removed enum. prefix
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"

# 2. Main Medical Request Model
class MedicalRequest(SQLModel, table=True):
    __tablename__ = "medical_requests"

    id: uuid_pkg.UUID = Field(default_factory=uuid_pkg.uuid4, primary_key=True)
    student_roll_no: str = Field(index=True)
    department_id: str
    from_date: date
    to_date: date
    reason: str
    document_path: str
    status: MedicalStatus = Field(default=MedicalStatus.PENDING)
    hod_remark: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

    # Relationship to the OCR processing history
    jobs: List["MedicalProcessingJob"] = Relationship(back_populates="request")

# 3. OCR / Background Task Tracking Model
class MedicalProcessingJob(SQLModel, table=True):
    __tablename__ = "medical_processing_jobs"

    id: uuid_pkg.UUID = Field(default_factory=uuid_pkg.uuid4, primary_key=True)
    medical_request_id: uuid_pkg.UUID = Field(foreign_key="medical_requests.id")
    ocr_text: Optional[str] = None
    extracted_from_date: Optional[date] = None
    extracted_to_date: Optional[date] = None
    confidence_score: float = 0.0
    
    # Using the ProcessingStatus enum for consistency
    processing_status: ProcessingStatus = Field(default=ProcessingStatus.PENDING)
    processed_at: datetime = Field(default_factory=datetime.utcnow)

    request: MedicalRequest = Relationship(back_populates="jobs")