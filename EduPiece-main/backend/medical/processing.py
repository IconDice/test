import pytesseract
from pdf2image import convert_from_path
import re
from datetime import datetime
from typing import Tuple, Optional, Any

def ocr_pdf(pdf_path: str) -> Tuple[str, float]:
    try:
        images = convert_from_path(pdf_path)
        full_text = ""
        for img in images:
            full_text += pytesseract.image_to_string(img)
        return full_text, 0.8
    except Exception:
        return "", 0.0

def extract_dates(text: str) -> Tuple[Optional[Any], Optional[Any]]:
    # Broad pattern for DD/MM/YYYY or DD-MM-YYYY
    pattern = r"(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})"
    matches = re.findall(pattern, text)
    
    if len(matches) >= 2:
        try:
            # Attempt to parse first two dates found
            d1 = datetime.strptime(matches[0].replace('-', '/'), "%d/%m/%Y").date()
            d2 = datetime.strptime(matches[1].replace('-', '/'), "%d/%m/%Y").date()
            return d1, d2
        except:
            pass
    return None, None

def validate_dates(declared_from, declared_to, extracted_from, extracted_to, semester_start, semester_end, max_days=7):
    if not extracted_from or not extracted_to:
        return False
    # Ensure AI extracted dates match student declaration
    return declared_from == extracted_from and declared_to == extracted_to