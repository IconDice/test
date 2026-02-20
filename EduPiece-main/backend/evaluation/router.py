import os
import uuid
import pytesseract
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
from typing import List
from pdf2image import convert_from_path
from PIL import Image

from config import UPLOAD_DIR

# --- WINDOWS CONFIGURATION (CRITICAL) ---
# Update these paths if you installed Tesseract or Poppler somewhere else
TESSERACT_EXE = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
POPPLER_BIN = r'C:\poppler\Library\bin' 

# Configure Tesseract
if os.path.exists(TESSERACT_EXE):
    pytesseract.pytesseract.tesseract_cmd = TESSERACT_EXE
else:
    print(f"WARNING: Tesseract not found at {TESSERACT_EXE}")

router = APIRouter(tags=["AI Evaluation"])

class EvaluationResult(BaseModel):
    score: int
    total_marks: int
    extracted_text: str
    missing_keywords: List[str]
    matched_keywords: List[str]
    feedback: str

@router.post("/evaluate", response_model=EvaluationResult)
async def evaluate_answer_sheet(
    file: UploadFile = File(...),
    keywords: str = Form(..., description="Comma separated keywords"),
    total_marks: int = Form(10)
):
    # 1. Save and Preprocess Image
    filename = f"{uuid.uuid4()}_{file.filename}"
    file_path = os.path.join(UPLOAD_DIR, filename)
    
    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)

    # 2. Extract Text (OCR)
    try:
        extracted_text = ""
        # Handle PDF
        if filename.lower().endswith('.pdf'):
            # We must pass the poppler_path explicitly on Windows
            images = convert_from_path(file_path, poppler_path=POPPLER_BIN)
            for img in images:
                extracted_text += pytesseract.image_to_string(img) + "\n"
        
        # Handle Images (JPG, PNG)
        else:
            img = Image.open(file_path)
            extracted_text = pytesseract.image_to_string(img)
            
    except Exception as e:
        print(f"OCR ERROR: {str(e)}") # Print error to backend terminal
        raise HTTPException(status_code=500, detail=f"OCR Engine Failed: {str(e)}")

    # 3. AI Grading Logic (Keyword Density Matching)
    clean_text = extracted_text.lower()
    keyword_list = [k.strip().lower() for k in keywords.split(',') if k.strip()]
    
    matched = []
    missing = []
    
    for key in keyword_list:
        if key in clean_text:
            matched.append(key)
        else:
            missing.append(key)
    
    # Calculate Score
    if not keyword_list:
        calculated_score = 0
    else:
        ratio = len(matched) / len(keyword_list)
        calculated_score = round(ratio * total_marks)

    # Generate Feedback
    if calculated_score == total_marks:
        feedback = "Excellent! Perfect answer."
    elif calculated_score >= total_marks * 0.7:
        feedback = "Good job, but missed a few key points."
    elif calculated_score >= total_marks * 0.4:
        feedback = "Average. Needs more detail on core concepts."
    else:
        feedback = "Poor. Key concepts are missing."

    return EvaluationResult(
        score=calculated_score,
        total_marks=total_marks,
        extracted_text=extracted_text,
        missing_keywords=missing,
        matched_keywords=matched,
        feedback=feedback
    )