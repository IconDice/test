from sqlmodel import create_engine, Session, SQLModel
from config import DB_URL

# echo=False for production to reduce log noise
engine = create_engine(DB_URL, echo=False)

def init_db():
    SQLModel.metadata.create_all(engine)

def get_db():
    with Session(engine) as session:
        yield session