from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional

class StudentCreate(BaseModel):
    roll_no: str = Field(..., min_length=3, max_length=50)
    name: str = Field(..., min_length=3, max_length=150) # Changed from full_name to name
    department_id: str
    semester: int
    user_id: UUID

class StudentResponse(BaseModel):
    id: UUID
    roll_no: str
    name: str # Changed from full_name to name
    department_id: str
    semester: int
    user_id: UUID

    class Config:
        from_attributes = True