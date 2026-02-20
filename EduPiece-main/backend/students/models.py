from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
import uuid as uuid_pkg

class Student(SQLModel, table=True):
    __tablename__ = "students"

    id: uuid_pkg.UUID = Field(
        default_factory=uuid_pkg.uuid4,
        primary_key=True,
        index=True
    )
    user_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    roll_no: str = Field(index=True, unique=True)
    name: str
    department_id: str
    semester: int

    # Relationship to attendance
    # (Note: attendance.models.AttendanceRecord handles the other side)