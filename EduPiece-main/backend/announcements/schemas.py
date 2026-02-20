from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import uuid

class AnnounceCreate(BaseModel):
    message_type: str # "TEXT", "FILE", "POLL"
    content: Optional[str] = None
    tags: List[str]
    poll_options: Optional[List[str]] = None

class ReactionCreate(BaseModel):
    announcement_id: int
    emoji: str

class GroupCreate(BaseModel):
    name: str

class JoinGroup(BaseModel):
    invite_link: str
    role: Optional[str] = "MEMBER" # <--- THIS IS REQUIRED