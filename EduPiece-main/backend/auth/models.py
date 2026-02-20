from sqlmodel import SQLModel, Field
from typing import Optional
import uuid as uuid_pkg

class User(SQLModel, table=True):
    __tablename__ = "users"

    id: uuid_pkg.UUID = Field(
        default_factory=uuid_pkg.uuid4,
        primary_key=True,
        index=True,
        nullable=False
    )
    username: str = Field(index=True, unique=True)
    full_name: str # Merged from Project A
    email: Optional[str] = Field(default=None)
    password_hash: str
    role: str = Field(default="STUDENT") # STUDENT, TEACHER, HOD
    is_active: bool = Field(default=True)