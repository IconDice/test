import pytesseract
from pdf2image import convert_from_path
import os
import re

# 1. SETUP PATHS - Update these to your actual installation folders
TESSERACT_EXE = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
POPPLER_BIN = r'C:\poppler\Library\bin' # <--- DOUBLE CHECK THIS PATH

pytesseract.pytesseract.tesseract_cmd = TESSERACT_EXE

def test_extraction(pdf_path):
    print(f"\n--- Starting OCR Test on: {os.path.basename(pdf_path)} ---")
    
    try:
        # 2. C ONVERT PDF TO IMAGE
        print("[1/3] Converting PDF to images using Poppler...")
        # Note: 'poppler_path' must be a keyword argument
        images = convert_from_path(pdf_path, poppler_path=POPPLER_BIN)
        
        full_text = ""
        for i, img in enumerate(images):
            print(f"      Processing page {i+1}...")
            # 3. OCR EXTRACTION
            text = pytesseract.image_to_string(img)
            full_text += text

        print("\n[2/3] Raw Text Extracted:")
        print("-" * 30)
        # Show first 500 characters so we can see the "quality" of the OCR
        print(full_text[:500] if full_text.strip() else "!!! NO TEXT FOUND !!!")
        print("-" * 30)

        # 4. SEARCH FOR DATES
        print("\n[3/3] Searching for dates...")
        date_pattern = r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})'
        found_dates = re.findall(date_pattern, full_text)

        if found_dates:
            print(f"✅ Success! Found dates: {found_dates}")
        else:
            print("⚠️ OCR worked, but no dates (DD/MM/YYYY) were detected in the text.")

    except Exception as e:
        print(f"🚨 CRITICAL ERROR: {str(e)}")
        print("\nQuick Fix Tips:")
        print(f"1. Check if {POPPLER_BIN} contains 'pdfinfo.exe'")
        print(f"2. Check if {TESSERACT_EXE} exists.")

if __name__ == "__main__":
    # Point to your test file
    SAMPLE_FILE = r"D:\College_APP\backend\uploads\medical\test.pdf"
    
    if os.path.exists(SAMPLE_FILE):
        test_extraction(SAMPLE_FILE)
    else:
        print(f"❌ File not found: {SAMPLE_FILE}")