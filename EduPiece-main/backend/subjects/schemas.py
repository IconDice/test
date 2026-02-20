from pydantic import BaseModel, Field
from uuid import UUID

class SubjectCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=20)
    name: str = Field(..., min_length=3, max_length=150)
    department_id: str
    semester: int # Added to match model
    faculty_id: UUID

class SubjectResponse(BaseModel):
    id: UUID
    code: str
    name: str
    department_id: str
    semester: int
    faculty_id: UUID

    class Config:
        from_attributes = True