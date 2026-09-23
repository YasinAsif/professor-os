"""ProfessorOS – HEC/OBE Bloom's Taxonomy Cognitive Quality Gate Validator.

Features:
  - Validates that assessments conform to HEC and NCEAC accreditation rules:
      1. CLO Mapping: 100% of questions must link to a recognized Course Learning Outcome.
      2. Cognitive Balance: Prevents rote-memorization papers (> 30% C1 disallowed).
      3. Higher-Order Cognitive Demand: Enforces at least 30% C3+ (Applying, Analyzing, Evaluating, Creating).
  - Directly updates 'quiz_configs.bloom_gate_passed' in the database.
  - Emits actionable pedagogical guidance to instructors on how to rebalance papers.
"""

import logging
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger("professor_os.blooms_gate")


class BloomsGatePolicy(BaseModel):
    """Accreditation constraints for assessment cognitive balance."""
    max_c1_percentage: float = 30.0         # Max allowed C1 (Remembering/Rote recall)
    min_higher_order_pct: float = 30.0      # Min required C3+ (Applying, Analyzing, Evaluating, Creating)
    require_full_clo_mapping: bool = True   # Every question in this quiz must be mapped to a CLO (no untagged items). Does NOT require one quiz to cover all course CLOs.
    min_questions_count: int = 1            # Minimum questions required to validate


class BloomsGateResult(BaseModel):
    """Formal audit report produced by the Bloom's Gate validator."""
    quiz_id: str
    is_approved: bool
    bloom_distribution: Dict[str, float] = Field(description="Percentage distribution of C1 through C6")
    total_questions: int
    unmapped_question_count: int
    clo_coverage_percentage: float
    violations: List[str]
    recommendations: List[str]


class BloomsGateValidator:
    """Evaluates question sets against HEC Bloom's Taxonomy accreditation standards."""

    def __init__(self, policy: Optional[BloomsGatePolicy] = None):
        self.policy = policy or BloomsGatePolicy()

    def evaluate_distribution(
        self,
        quiz_id: str,
        questions: List[Dict[str, Any]],
    ) -> BloomsGateResult:
        """Pure evaluation function assessing cognitive distribution and CLO mapping."""
        total = len(questions)
        if total == 0:
            return BloomsGateResult(
                quiz_id=quiz_id,
                is_approved=False,
                bloom_distribution={f"C{i}": 0.0 for i in range(1, 7)},
                total_questions=0,
                unmapped_question_count=0,
                clo_coverage_percentage=0.0,
                violations=["Assessment has 0 questions. Cannot pass quality gate."],
                recommendations=["Add questions to the assessment before requesting publication approval."],
            )

        # 1. Count Bloom's Levels (C1-C6)
        counts: Dict[str, int] = {f"C{i}": 0 for i in range(1, 7)}
        unmapped_clos = 0

        for q in questions:
            bloom_raw = str(q.get("bloom_level", "C2")).upper()
            if bloom_raw in counts:
                counts[bloom_raw] += 1
            else:
                counts["C2"] += 1  # Default fallback if unrecognized

            # Check CLO mapping
            clo_val = q.get("clo_id") or q.get("clo_suggestion")
            if not clo_val:
                unmapped_clos += 1

        # 2. Compute percentages
        dist_pct: Dict[str, float] = {
            level: round((count / total) * 100.0, 1) for level, count in counts.items()
        }

        c1_pct = dist_pct.get("C1", 0.0)
        higher_order_pct = sum(dist_pct.get(f"C{i}", 0.0) for i in range(3, 7))
        clo_coverage = round(((total - unmapped_clos) / total) * 100.0, 1)

        # 3. Check Violations
        violations: List[str] = []
        recommendations: List[str] = []

        # Gate A: CLO mapping
        if self.policy.require_full_clo_mapping and unmapped_clos > 0:
            violations.append(
                f"HEC OBE Violation: {unmapped_clos} of {total} questions lack CLO alignment ({clo_coverage}% mapped)."
            )
            recommendations.append("Map all unaligned questions to an approved Course Learning Outcome (CLO).")

        # Gate B: Excessive Rote Recall (C1)
        if c1_pct > self.policy.max_c1_percentage:
            violations.append(
                f"Cognitive Quality Gate Violation: C1 (Remembering) is {c1_pct}%, exceeding the maximum allowed {self.policy.max_c1_percentage}%."
            )
            recommendations.append(
                f"Replace or elevate {round((c1_pct - self.policy.max_c1_percentage) * total / 100)} C1 recall questions to C3 (Applying) or C4 (Analyzing) problems."
            )

        # Gate C: Insufficient Higher-Order Problems (C3-C6)
        if higher_order_pct < self.policy.min_higher_order_pct:
            violations.append(
                f"Academic Rigor Gate Violation: Higher-order questions (C3-C6) represent only {higher_order_pct}%, below the required {self.policy.min_higher_order_pct}%."
            )
            recommendations.append(
                "Incorporate application problems, debugging scenarios, or algorithmic analysis questions to satisfy HEC accreditation standards."
            )

        is_approved = len(violations) == 0

        logger.info(
            "Bloom's Gate for Quiz %s: Approved=%s | C1=%.1f%% | C3+=%.1f%% | CLO Coverage=%.1f%%",
            quiz_id,
            is_approved,
            c1_pct,
            higher_order_pct,
            clo_coverage,
        )

        return BloomsGateResult(
            quiz_id=quiz_id,
            is_approved=is_approved,
            bloom_distribution=dist_pct,
            total_questions=total,
            unmapped_question_count=unmapped_clos,
            clo_coverage_percentage=clo_coverage,
            violations=violations,
            recommendations=recommendations,
        )


async def validate_and_update_quiz_gate(
    quiz_id: str,
    db: AsyncSession,
    policy: Optional[BloomsGatePolicy] = None,
) -> BloomsGateResult:
    """Asynchronous validator that queries database questions, runs gate checks,

    and directly writes the boolean status to 'quiz_configs.bloom_gate_passed'.
    """
    from sqlalchemy import text

    # Query questions associated with this quiz via quiz_questions association
    query = text("""
        SELECT
            qb.question_id,
            qb.bloom_level,
            qb.clo_id,
            qb.difficulty
        FROM question_bank qb
        JOIN quiz_questions qq ON qq.question_id = qb.question_id
        WHERE qq.quiz_id = :quiz_id
    """)
    res = await db.execute(query, {"quiz_id": quiz_id})
    rows = res.mappings().all()

    if not rows:
        # Fallback: all approved questions in the course if not individually linked
        fallback_query = text("""
            SELECT
                qb.question_id,
                qb.bloom_level,
                qb.clo_id,
                qb.difficulty
            FROM question_bank qb
            JOIN quiz_configs qc ON qc.quiz_id = :quiz_id
            JOIN assignments a ON a.id = qc.assignment_id
            WHERE qb.course_id = a.course_id AND qb.status = 'APPROVED'
        """)
        res = await db.execute(fallback_query, {"quiz_id": quiz_id})
        rows = res.mappings().all()

    questions = [dict(r) for r in rows]

    validator = BloomsGateValidator(policy=policy)
    result = validator.evaluate_distribution(quiz_id=quiz_id, questions=questions)

    # Persist gate status into quiz_configs
    update_stmt = text("""
        UPDATE quiz_configs
        SET bloom_gate_passed = :passed
        WHERE quiz_id = :quiz_id
    """)
    await db.execute(update_stmt, {"passed": result.is_approved, "quiz_id": quiz_id})
    await db.commit()

    return result
