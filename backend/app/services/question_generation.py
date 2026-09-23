"""ProfessorOS – AI Question Generation Pipeline using Llama-3.3-70B-Versatile.

Features:
  - Dispatched via Celery on 'question_gen_queue'.
  - Uses Pipeline 3 (llama-3.3-70b-versatile on Groq with OpenRouter failover).
  - Enforces strict Pydantic v2 validation.
  - Generates Bloom's Taxonomy cognitive levels (C1 to C6), CLO alignments,
    difficulty estimates (0.1 - 1.0), and pedagogical distractor rationales.
  - Persists generated questions directly into PostgreSQL 'question_bank'.
"""

import json
import logging
import uuid
from enum import Enum
from typing import Any, Dict, List, Optional
from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator

from celery import shared_task
from app.config.llm_config import LLMPipeline, get_llm_client
from app.config.settings import get_settings

logger = logging.getLogger("professor_os.question_gen")
settings = get_settings()


class BloomLevel(str, Enum):
    """HEC / Bloom's Revised Taxonomy Cognitive Levels."""
    C1 = "C1"  # Remembering
    C2 = "C2"  # Understanding
    C3 = "C3"  # Applying
    C4 = "C4"  # Analyzing
    C5 = "C5"  # Evaluating
    C6 = "C6"  # Creating


class QuestionType(str, Enum):
    """Categorical question formats."""
    MCQ = "MCQ"
    SHORT_ANSWER = "SHORT_ANSWER"
    ESSAY = "ESSAY"


class DistractorRationale(BaseModel):
    """Pedagogical justification for incorrect options."""
    model_config = ConfigDict(extra="ignore")
    option_key: str = Field(default="", description="Option letter or text, e.g., 'A', 'B', 'C'")
    misconception: str = Field(default="", description="Identifies the common student misconception this distractor exploits")


class GeneratedQuestionSchema(BaseModel):
    """Single question schema with strict pedagogical attributes."""
    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    question_text: str = Field(
        validation_alias=AliasChoices("question_text", "question", "text", "stem"),
        description="The formal academic prompt of the question",
    )
    question_type: QuestionType = Field(
        default=QuestionType.MCQ,
        validation_alias=AliasChoices("question_type", "type"),
    )
    bloom_level: BloomLevel = Field(
        default=BloomLevel.C2,
        validation_alias=AliasChoices("bloom_level", "bloom", "level"),
        description="Bloom's taxonomy cognitive domain level (C1 to C6)",
    )
    clo_suggestion: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("clo_suggestion", "clo", "clo_id"),
        description="Suggested Course Learning Outcome code, e.g. 'CLO-1'",
    )
    difficulty_estimate: float = Field(
        default=0.5,
        ge=0.1,
        le=1.0,
        validation_alias=AliasChoices("difficulty_estimate", "difficulty"),
        description="Normalized difficulty rating from 0.1 to 1.0",
    )
    options: Optional[List[Any]] = Field(default=None, description="List of candidate answers for MCQ")
    correct_answer: str = Field(
        default="",
        validation_alias=AliasChoices("correct_answer", "answer", "correct_option", "correct"),
        description="The definitive correct answer text or option label",
    )
    distractor_rationales: Optional[List[DistractorRationale]] = Field(
        default=None,
        description="List explaining why each distractor is incorrect and what error it tests",
    )
    explanation: Optional[str] = Field(
        default="Standard pedagogical explanation.",
        validation_alias=AliasChoices("explanation", "rational", "rationale"),
        description="Comprehensive pedagogical explanation",
    )
    recommended_points: float = Field(default=1.0, ge=0.5)

    @field_validator("options", mode="before")
    @classmethod
    def normalize_options(cls, v):
        if not v or not isinstance(v, list):
            return v
        normalized = []
        for item in v:
            if isinstance(item, dict):
                label = item.get("label") or item.get("key") or ""
                text = item.get("text") or item.get("option") or item.get("value") or ""
                if label and text:
                    normalized.append(f"{label}: {text}")
                else:
                    normalized.append(str(text or label or item))
            else:
                normalized.append(str(item))
        return normalized

    @field_validator("correct_answer", mode="before")
    @classmethod
    def normalize_correct_answer(cls, v):
        if isinstance(v, dict):
            return str(v.get("text") or v.get("label") or v.get("option") or v)
        return str(v) if v is not None else ""


class QuestionGenerationBatchOutput(BaseModel):
    """Batch container for generated questions."""
    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    topic: Optional[str] = Field(default="Academic Assessment Topic")
    target_bloom_distribution: Optional[List[str]] = Field(default_factory=lambda: ["C2", "C3", "C4"])
    questions: List[GeneratedQuestionSchema]


SYSTEM_PROMPT = """You are a Distinguished Professor and Academic Assessment Specialist in Computer Science and Software Engineering at a premier university.
Your task is to author high-quality, rigorous assessment questions aligned with HEC and PEC Outcome-Based Education (OBE) guidelines.

Rules:
1. Every question must be classified into a precise Bloom's Taxonomy cognitive level (C1: Recall, C2: Comprehend, C3: Apply/Execute, C4: Analyze/Debug, C5: Evaluate/Defend, C6: Create/Synthesize).
2. For Multiple Choice Questions (MCQs):
   - Provide exactly 4 options.
   - The correct answer must be unambiguously accurate.
   - The 3 distractors must be PLAUSIBLE and rooted in real-world student misconceptions or partial understanding (no joke options, no 'all of the above').
   - For every distractor, state the specific misconception it targets.
3. Align each question with a plausible Course Learning Outcome (e.g. 'CLO-1', 'CLO-2').
4. Calibrate the difficulty_estimate accurately between 0.1 and 1.0.
5. Output must strictly conform to the required JSON schema.
"""


def _generate_questions_core(
    topic_or_context: str,
    num_questions: int = 5,
    bloom_levels: Optional[List[str]] = None,
    question_type: str = "MCQ",
    clo_guidelines: Optional[str] = None,
) -> QuestionGenerationBatchOutput:
    """Executes the prompt and validation cycle via LLMClient Pipeline 3."""
    llm = get_llm_client()

    target_blooms = bloom_levels or ["C2", "C3", "C4"]
    blooms_str = ", ".join(target_blooms)

    user_prompt = f"""Generate {num_questions} academic assessment questions on the following course material:

--- CONTEXT / MATERIAL ---
{topic_or_context[:6000]}
--------------------------

Specifications:
- Number of questions: {num_questions}
- Question Type: {question_type}
- Targeted Bloom's Levels: {blooms_str}
- Course Learning Outcome Guidelines: {clo_guidelines or 'Map logically to standard undergraduate CS course outcomes'}

Ensure the distractors are pedagogically rich with explicit misconception explanations.
Return output adhering strictly to the JSON schema.
"""

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_prompt},
    ]

    logger.info("Requesting %d questions on '%s' via Llama-3.3-70B-Versatile...", num_questions, topic_or_context[:50])
    return llm.complete_structured(
        pipeline=LLMPipeline.QUESTION_GEN,
        messages=messages,
        response_model=QuestionGenerationBatchOutput,
        temperature=0.4,
    )


# ── Celery Task Definition ──────────────────────────────────────────

@shared_task(
    name="generate_questions_task",
    bind=True,
    queue=settings.QUEUE_QUESTION_GEN,
    max_retries=2,
    default_retry_delay=20,
)
def generate_questions_task(
    self,
    job_id: str,
    course_id: int,
    created_by_user_id: int,
    topic_or_context: str,
    num_questions: int = 5,
    bloom_levels: Optional[List[str]] = None,
    question_type: str = "MCQ",
    clo_guidelines: Optional[str] = None,
) -> Dict[str, Any]:
    """Celery background task for asynchronous question authoring.

    Dispatched to the dedicated 'question_gen_queue'.
    Updates DB job status and inserts into 'question_bank'.
    """
    logger.info("🚀 [CELERY:question_gen_queue] Starting Question Generation Job: %s for Course %s", job_id, course_id)

    try:
        # 1. Run LLM Generation
        batch: QuestionGenerationBatchOutput = _generate_questions_core(
            topic_or_context=topic_or_context,
            num_questions=num_questions,
            bloom_levels=bloom_levels,
            question_type=question_type,
            clo_guidelines=clo_guidelines,
        )

        logger.info("Successfully generated %d questions for job %s", len(batch.questions), job_id)

        # 2. Persist to PostgreSQL (Sync DB Session for Celery worker)
        from sqlalchemy import create_engine, text
        sync_db_url = settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql+psycopg://")
        engine = create_engine(sync_db_url)

        with engine.begin() as conn:
            # Update job status to PROCESSING
            task_id = self.request.id if hasattr(self, "request") and self.request else str(uuid.uuid4())
            conn.execute(
                text("""
                    UPDATE question_generation_jobs
                    SET status = 'PROCESSING', celery_task_id = :task_id
                    WHERE job_id = :job_id
                """),
                {"job_id": job_id, "task_id": task_id},
            )

            # Insert into question_bank with DRAFT status for professor review
            inserted_count = 0
            for q in batch.questions:
                q_id = str(uuid.uuid4())
                options_json = json.dumps(q.options) if q.options else None
                distractors_json = (
                    json.dumps([d.model_dump() for d in q.distractor_rationales])
                    if q.distractor_rationales
                    else None
                )

                # Try resolving CLO id if suggestion provided
                clo_uuid = None
                if q.clo_suggestion:
                    res_clo = conn.execute(
                        text("SELECT clo_id FROM clo_definitions WHERE course_id = :cid AND code = :code"),
                        {"cid": course_id, "code": q.clo_suggestion},
                    ).first()
                    if res_clo:
                        clo_uuid = str(res_clo[0])

                conn.execute(
                    text("""
                        INSERT INTO question_bank (
                            question_id, course_id, created_by, question_text,
                            question_type, options, correct_answer, bloom_level,
                            difficulty, clo_id, status, metadata_json
                        ) VALUES (
                            :q_id, :course_id, :created_by, :question_text,
                            :question_type, :options, :correct_answer, :bloom_level,
                            :difficulty, :clo_id, 'DRAFT', :metadata_json
                        )
                    """),
                    {
                        "q_id": q_id,
                        "course_id": course_id,
                        "created_by": created_by_user_id,
                        "question_text": q.question_text,
                        "question_type": q.question_type.value,
                        "options": options_json,
                        "correct_answer": q.correct_answer,
                        "bloom_level": q.bloom_level.value,
                        "difficulty": q.difficulty_estimate,
                        "clo_id": clo_uuid,
                        "metadata_json": json.dumps({
                            "explanation": q.explanation,
                            "distractor_rationales": distractors_json,
                            "recommended_points": q.recommended_points,
                            "job_id": job_id,
                        }),
                    },
                )
                inserted_count += 1

            # Mark job DONE
            conn.execute(
                text("""
                    UPDATE question_generation_jobs
                    SET status = 'DONE', questions_generated = :count
                    WHERE job_id = :job_id
                """),
                {"job_id": job_id, "count": inserted_count},
            )

        logger.info("✅ [CELERY:question_gen_queue] Job %s completed. Inserted %d questions into question_bank.", job_id, inserted_count)

        return {
            "status": "completed",
            "job_id": job_id,
            "course_id": course_id,
            "questions_generated": inserted_count,
            "topic": batch.topic,
        }

    except Exception as exc:
        logger.error("❌ [CELERY:question_gen_queue] Job %s failed: %s", job_id, exc, exc_info=True)

        # Mark job FAILED in DB
        try:
            from sqlalchemy import create_engine, text
            sync_db_url = settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql+psycopg://")
            engine = create_engine(sync_db_url)
            with engine.begin() as conn:
                conn.execute(
                    text("UPDATE question_generation_jobs SET status = 'FAILED' WHERE job_id = :job_id"),
                    {"job_id": job_id},
                )
        except Exception as db_err:
            logger.error("Failed to mark job as FAILED in DB: %s", db_err)

        raise self.retry(exc=exc)
