from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlmodel import Session, select
from database import get_db
from auth.models import User
from core.security import verify_password, create_access_token

router = APIRouter(tags=["Auth"])

@router.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    # Logic handles both username and ID login
    statement = select(User).where(User.username == form_data.username)
    user = db.exec(statement).first()

    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    token = create_access_token(
        data={"sub": str(user.id), "role": user.role, "username": user.username}
    )

    return {
        "access_token": token, 
        "token_type": "bearer", 
        "role": user.role,
        "full_name": user.full_name,
        "user_id": str(user.id) # Useful for frontend
    }