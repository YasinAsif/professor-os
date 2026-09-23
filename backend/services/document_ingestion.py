"""Re-export of app.services.document_ingestion to support root-level services imports."""

from app.services.document_ingestion import (
    DoclingPipeline,
    ingest_course_document_task,
    DocumentIngestionError,
)

__all__ = [
    "DoclingPipeline",
    "ingest_course_document_task",
    "DocumentIngestionError",
]
