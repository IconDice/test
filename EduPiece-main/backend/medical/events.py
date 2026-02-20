import logging
from sqlmodel import Session, select
from medical.models import MedicalRequest, MedicalProcessingJob, ProcessingStatus, MedicalStatus
from medical.processing import ocr_pdf, extract_dates, validate_dates
from attendance.service import apply_medical_leave

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def process_medical_request(db: Session, request_id):
    try:
        # 1. Fetch Request
        medical_req = db.get(MedicalRequest, request_id)
        if not medical_req or medical_req.status != MedicalStatus.APPROVED:
            return

        # 2. OCR Processing
        ocr_text, confidence = ocr_pdf(medical_req.document_path)
        
        # 3. Intelligent Date Extraction
        extracted_from, extracted_to = extract_dates(ocr_text)

        # 4. Validation
        semester_start = medical_req.from_date.replace(month=1, day=1) 
        semester_end = medical_req.from_date.replace(month=6, day=30)

        is_valid = validate_dates(
            declared_from=medical_req.from_date,
            declared_to=medical_req.to_date,
            extracted_from=extracted_from,
            extracted_to=extracted_to,
            semester_start=semester_start,
            semester_end=semester_end
        )

        # 5. Record Job
        job = MedicalProcessingJob(
            medical_request_id=request_id,
            ocr_text=ocr_text,
            extracted_from_date=extracted_from,
            extracted_to_date=extracted_to,
            confidence_score=confidence,
            processing_status=ProcessingStatus.COMPLETED if is_valid else ProcessingStatus.FAILED
        )
        db.add(job)
        
        # 6. Apply Attendance
        if is_valid:
            apply_medical_leave(
                db, 
                medical_req.student_roll_no, 
                medical_req.from_date, 
                medical_req.to_date
            )
            logger.info(f"Auto-updated attendance for request {request_id}")
        else:
            logger.warning(f"OCR mismatch for request {request_id}")

        db.commit()

    except Exception as e:
        db.rollback()
        logger.error(f"Error in background processing: {str(e)}")