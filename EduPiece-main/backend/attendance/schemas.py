from pydantic import BaseModel, field_validator
from datetime import date
from typing import List, Literal
from uuid import UUID

class RollListRequest(BaseModel):
    subject_code: str
    session_date: date

class RollListResponse(BaseModel):
    date: date
    roll_numbers: List[str]
class AttendanceItem(BaseModel):
    roll_no: str
    status: Literal["PRESENT", "ABSENT"]

    @field_validator("roll_no")
    @classmethod
    def validate_roll(cls, v: str):
        if not v or not v.strip():
            raise ValueError("Invalid roll number")
        return v.strip()


class AttendanceSubmitRequest(BaseModel):
    subject_code: str
    session_date: date
    records: List[AttendanceItem]


class AttendanceSessionResponse(BaseModel):
    session_id: UUID
    subject_id: str
    date: date
