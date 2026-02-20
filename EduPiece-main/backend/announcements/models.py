from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
import uuid as uuid_pkg
from sqlalchemy import JSON, Column
from auth.models import User

# --- Core Group Models ---
class AnnounceGroup(SQLModel, table=True):
    __tablename__ = "announce_groups"
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    admin_id: uuid_pkg.UUID = Field(foreign_key="users.id") # Creator/Admin
    invite_link: str = Field(unique=True, index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class AnnounceMember(SQLModel, table=True):
    __tablename__ = "announce_members"
    id: Optional[int] = Field(default=None, primary_key=True)
    group_id: int = Field(foreign_key="announce_groups.id")
    user_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    role: str = Field(default="MEMBER") # "ADMIN" or "MEMBER"
    joined_at: datetime = Field(default_factory=datetime.utcnow)

# --- Tags ---
class GroupTag(SQLModel, table=True):
    __tablename__ = "announce_tags"
    id: Optional[int] = Field(default=None, primary_key=True)
    group_id: int = Field(foreign_key="announce_groups.id")
    name: str
    usage_count: int = Field(default=0)

# --- Announcements & Attachments ---
class Announcement(SQLModel, table=True):
    __tablename__ = "announcements"
    id: Optional[int] = Field(default=None, primary_key=True)
    group_id: int = Field(foreign_key="announce_groups.id")
    admin_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    
    message_type: str # "TEXT", "FILE", "POLL"
    content: Optional[str] = None # Text message or Poll Question
    file_url: Optional[str] = None # For PDF or Image
    
    # Store assigned tags as a simple JSON list of strings to avoid complex joins
    tags: List[str] = Field(default=[], sa_column=Column(JSON)) 
    created_at: datetime = Field(default_factory=datetime.utcnow)

# --- Polls & Reactions ---
class PollOption(SQLModel, table=True):
    __tablename__ = "announce_poll_options"
    id: Optional[int] = Field(default=None, primary_key=True)
    announcement_id: int = Field(foreign_key="announcements.id")
    option_text: str

class PollVote(SQLModel, table=True):
    __tablename__ = "announce_poll_votes"
    id: Optional[int] = Field(default=None, primary_key=True)
    option_id: int = Field(foreign_key="announce_poll_options.id")
    user_id: uuid_pkg.UUID = Field(foreign_key="users.id")

class Reaction(SQLModel, table=True):
    __tablename__ = "announce_reactions"
    id: Optional[int] = Field(default=None, primary_key=True)
    announcement_id: int = Field(foreign_key="announcements.id")
    user_id: uuid_pkg.UUID = Field(foreign_key="users.id")
    emoji: str # e.g., "👍", "❤️"