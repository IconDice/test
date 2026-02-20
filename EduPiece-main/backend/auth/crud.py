from sqlmodel import Session, select
from auth.models import User

def get_user_by_username(db: Session, username: str):
    # Pure SQLModel syntax: select(Model).where(...)
    statement = select(User).where(User.username == username)
    return db.exec(statement).first()

def create_user(
    db: Session,
    username: str,
    password_hash: str,
    role: str,
    linked_id: str | None = None,
):
    user = User(
        username=username,
        password_hash=password_hash,
        role=role,
        linked_id=linked_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user