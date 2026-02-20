from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlmodel import Session, select
from database import get_db
from auth.models import User
from core.dependencies import get_current_user
from .models import *
from .schemas import *
import random, string, shutil, os, json, uuid
from config import UPLOAD_DIR

router = APIRouter()

def generate_invite():
    return ''.join(random.choices(string.ascii_letters + string.digits, k=8))

@router.post("/groups/create")
def create_group(data: GroupCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if user.role not in ["TEACHER", "HOD"]:
        raise HTTPException(status_code=403, detail="Only staff can create announcement groups.")
    
    group = AnnounceGroup(name=data.name, admin_id=user.id, invite_link=generate_invite())
    db.add(group)
    db.commit()
    db.refresh(group)
    
    member = AnnounceMember(group_id=group.id, user_id=user.id, role="ADMIN")
    db.add(member)
    
    default_tags = ["Notice", "Time Table", "Placement", "Internship"]
    for t in default_tags:
        db.add(GroupTag(group_id=group.id, name=t))
        
    db.commit()
    return group

@router.post("/groups/join")
def join_group(data: JoinGroup, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # 1. Strip the prefixes safely
    clean_invite = data.invite_link.replace("std@", "").replace("ad@", "")
    
    # 2. Find the group
    group = db.exec(select(AnnounceGroup).where(AnnounceGroup.invite_link == clean_invite)).first()
    if not group:
        raise HTTPException(status_code=404, detail="Invalid Invite Link")
    
    # 3. Determine the requested role safely (Prevents the AttributeError!)
    requested_role = getattr(data, "role", "MEMBER")
    
    # Force ADMIN if they used the ad@ code, regardless of what the frontend sent
    if data.invite_link.startswith("ad@"):
        requested_role = "ADMIN"
    elif data.invite_link.startswith("std@"):
        requested_role = "MEMBER"

    # 4. Check if they are already in the group
    existing = db.exec(select(AnnounceMember).where(
        AnnounceMember.group_id == group.id, AnnounceMember.user_id == user.id
    )).first()
    
    if existing:
        # Upgrade to Admin if they used the Admin link
        if existing.role != "ADMIN" and requested_role == "ADMIN":
            existing.role = "ADMIN"
            db.add(existing)
            db.commit()
            return {"message": f"Successfully upgraded to Admin in {group.name}"}
        
        return {"message": "You are already in this group"}
        
    # 5. Add new member
    member = AnnounceMember(group_id=group.id, user_id=user.id, role=requested_role)
    db.add(member)
    db.commit()
    return {"message": f"Successfully joined {group.name} as {requested_role}"}

@router.get("/groups/my")
def get_my_groups(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    memberships = db.exec(select(AnnounceMember).where(AnnounceMember.user_id == user.id)).all()
    group_ids = [m.group_id for m in memberships]
    if not group_ids: return []
    
    groups = db.exec(select(AnnounceGroup).where(AnnounceGroup.id.in_(group_ids))).all()
    
    result = []
    for g in groups:
        role = next(m.role for m in memberships if m.group_id == g.id)
        result.append({"id": g.id, "name": g.name, "role": role, "invite_link": g.invite_link})
    return result

@router.post("/groups/{group_id}/announce")
def create_announcement(
    group_id: int, 
    message_type: str = Form(...),
    content: Optional[str] = Form(None),
    tags: str = Form(...), 
    poll_options: Optional[str] = Form(None), 
    file: Optional[UploadFile] = File(None),
    user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    member = db.exec(select(AnnounceMember).where(
        AnnounceMember.group_id == group_id, AnnounceMember.user_id == user.id
    )).first()
    
    if not member or member.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Only admins can send announcements.")
        
    tag_list = json.loads(tags)
    if not tag_list: raise HTTPException(status_code=400, detail="At least one tag is required.")

    file_url = None
    if file:
        folder = os.path.join(UPLOAD_DIR, "announcements")
        os.makedirs(folder, exist_ok=True)
        ext = os.path.splitext(file.filename)[1]
        filename = f"{uuid.uuid4().hex}{ext}"
        file_path = os.path.join(folder, filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        file_url = f"/uploads/announcements/{filename}"

    ann = Announcement(
        group_id=group_id, admin_id=user.id, 
        message_type=message_type, content=content, tags=tag_list, file_url=file_url
    )
    db.add(ann)
    db.commit()
    db.refresh(ann)

    if message_type == "POLL" and poll_options:
        opts = json.loads(poll_options)
        for opt in opts:
            db.add(PollOption(announcement_id=ann.id, option_text=opt))
        db.commit()

    for t_name in tag_list:
        tag = db.exec(select(GroupTag).where(GroupTag.group_id == group_id, GroupTag.name == t_name)).first()
        if tag:
            tag.usage_count += 1
            db.add(tag)
        else:
            db.add(GroupTag(group_id=group_id, name=t_name, usage_count=1))
    db.commit()
    
    return {"message": "Announcement created"}

@router.get("/groups/{group_id}/messages")
def get_announcements(group_id: int, tag: Optional[str] = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not db.exec(select(AnnounceMember).where(AnnounceMember.group_id == group_id, AnnounceMember.user_id == user.id)).first():
        raise HTTPException(status_code=403, detail="Not a member")

    query = select(Announcement).where(Announcement.group_id == group_id).order_by(Announcement.created_at.asc())
    anns = db.exec(query).all()

    if tag: anns = [a for a in anns if tag in a.tags]

    result = []
    for a in anns:
        reactions = db.exec(select(Reaction).where(Reaction.announcement_id == a.id)).all()
        reaction_counts = {}
        for r in reactions:
            reaction_counts[r.emoji] = reaction_counts.get(r.emoji, 0) + 1
            
        item = {
            "id": a.id, "type": a.message_type, "content": a.content, 
            "file_url": a.file_url, "tags": a.tags, "created_at": a.created_at,
            "reactions": reaction_counts
        }
        
        if a.message_type == "POLL":
            opts = db.exec(select(PollOption).where(PollOption.announcement_id == a.id)).all()
            item["poll_options"] = [{"id": o.id, "text": o.option_text} for o in opts]
            
        result.append(item)
    return result

@router.post("/react")
def react_to_announcement(data: ReactionCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    existing = db.exec(select(Reaction).where(
        Reaction.announcement_id == data.announcement_id, Reaction.user_id == user.id
    )).first()
    
    if existing:
        existing.emoji = data.emoji
        db.add(existing)
    else:
        db.add(Reaction(announcement_id=data.announcement_id, user_id=user.id, emoji=data.emoji))
    db.commit()
    return {"status": "Reacted"}