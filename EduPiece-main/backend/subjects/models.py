from sqlmodel import SQLModel, Field
from typing import Optional
import uuid as uuid_pkg

class Subject(SQLModel, table=True):
    __tablename__ = "subjects"

    id: uuid_pkg.UUID = Field(
        default_factory=uuid_pkg.uuid4,
        primary_key=True,
        index=True
    )
    code: str = Field(index=True, unique=True)
    name: str
    department_id: str
    semester: int
    faculty_id: uuid_pkg.UUID = Field(foreign_key="users.id")