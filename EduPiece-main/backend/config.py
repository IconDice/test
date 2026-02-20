import os

# Database Configuration
DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:hunter@localhost:5432/college_db",
)

# Auth Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "super-secret-merged-key-2026")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440 # 24 Hours

# File Storage
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads", "medical")
os.makedirs(UPLOAD_DIR, exist_ok=True)