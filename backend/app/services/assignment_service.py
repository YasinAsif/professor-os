"""ProfessorOS – Assignment service (CRUD, HEC publish validation)."""

import json
import re
from typing import List, Optional

from sqlalchemy import delete, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.assignment import Assignment, AssignmentStatus, assignment_clo_table, assignment_ta_table
from app.models.course import CLO, Enrollment
from app.models.user import User
from app.services.assignment_access import can_access_assignment
from app.models.rubric import Rubric, RubricCriterion, RubricLevel, LevelName
from app.schemas.assignment import AssignmentCreate, AssignmentUpdate
from app.schemas.rubric import RubricCreate


def ensure_assignment_in_course(course_id: int, assignment_course_id: int) -> None:
    """Guard course-scoped routes against cross-course assignment IDs."""
    if course_id != assignment_course_id:
        raise PermissionError("Assignment not found in this course.")


def validate_assessment_rules(
    category: Optional[str],
    assignment_type: str,
    max_marks: float,
    weightage: Optional[float],
    description: Optional[str],
    existing_assignments: List[Assignment],
    editing_assignment_id: Optional[int] = None,
) -> None:
    cat = (category or "assignment").lower()
    a_type = (assignment_type or "text").lower()

    # 1. Edge Case 3: Enforce max 1 Midterm and 1 Final per course offering
    if cat in ("midterm", "final"):
        for other in existing_assignments:
            if other.id == editing_assignment_id:
                continue
            if (other.category or "").lower() == cat and (other.status or "").lower() != "archived":
                raise ValueError(f"This course offering already has an active {cat.title()}. Only 1 {cat.title()} is allowed.")

    # Parse questions from description if JSON
    questions = []
    if description and description.strip().startswith("{"):
        try:
            payload = json.loads(description)
            if isinstance(payload, dict):
                questions = payload.get("questions") or []
        except Exception:
            questions = []

    # 2. Category-specific rules (Requirement B)
    if cat == "midterm":
        if abs(max_marks - 20.0) > 0.001:
            raise ValueError("Midterm total marks must be fixed at 20.")
        if weightage is not None and abs(weightage - 20.0) > 0.001:
            raise ValueError("Midterm weightage must be fixed at 20 marks.")
        if a_type == "mcq":
            raise ValueError("MCQs are not allowed in Midterm exams. Short/long questions only.")
        if len(questions) > 4:
            raise ValueError(f"Midterm allows a maximum of 4 main questions (found {len(questions)}).")

    elif cat == "final":
        if abs(max_marks - 50.0) > 0.001:
            raise ValueError("Final total marks must be fixed at 50.")
        if weightage is not None and abs(weightage - 50.0) > 0.001:
            raise ValueError("Final weightage must be fixed at 50 marks.")
        if a_type == "mcq":
            raise ValueError("MCQs are not allowed in Final exams. Short/long questions only.")
        if len(questions) > 5:
            raise ValueError(f"Final allows a maximum of 5 main questions (found {len(questions)}).")

    elif cat == "project":
        if a_type != "file":
            raise ValueError("Project/Presentation must be a file upload for students.")
        if questions:
            raise ValueError("Project/Presentation does not allow questions.")
        if weightage is not None and (weightage < 0 or weightage > 30):
            raise ValueError("Internal assessment weightage cannot exceed 30 marks.")

    elif cat in ("quiz", "assignment"):
        if weightage is not None and (weightage < 0 or weightage > 30):
            raise ValueError("Internal assessment weightage cannot exceed 30 marks.")

    # 3. Sum of question/sub-part marks for Midterm and Final (Instruction 3)
    if cat in ("midterm", "final") and questions:
        total_q_marks = 0.0
        for qi, q in enumerate(questions, 1):
            parts = q.get("parts") or []
            if parts:
                part_sum = 0.0
                for pi, p in enumerate(parts):
                    part_sum += float(p.get("marks", 0.0))
                total_q_marks += part_sum
            else:
                total_q_marks += float(q.get("marks", 0.0))
        target = 20.0 if cat == "midterm" else 50.0
        if abs(total_q_marks - target) > 0.01:
            raise ValueError(f"Sum of question and sub-part marks for {cat.title()} must equal {int(target)} marks (currently {total_q_marks:.1f}).")

    # 4. Answer key validation (Requirement C)
    for qi, q in enumerate(questions, 1):
        q_text = (q.get("question") or "").strip()
        q_type = (q.get("type") or a_type).lower()
        if q_type == "mcq":
            options = q.get("options") or []
            valid_options = [opt for opt in options if str(opt).strip()]
            if len(valid_options) < 2:
                raise ValueError(f"Question {qi}: MCQ must have at least 2 non-empty options.")
            correct = q.get("correct")
            if correct is None or not (0 <= int(correct) < len(options)):
                raise ValueError(f"Question {qi}: MCQ must have a selected correct option.")
        else:
            # Short / Long question
            parts = q.get("parts") or []
            if parts:
                for pi, p in enumerate(parts):
                    part_label = p.get("part") or chr(ord("a") + pi)
                    ref_ans = (p.get("reference_answer") or "").strip()
                    if not ref_ans:
                        raise ValueError(f"Question {qi} part ({part_label}) is missing a reference answer.")
            else:
                ref_ans = (q.get("reference_answer") or "").strip()
                if not ref_ans:
                    raise ValueError(f"Question {qi} is missing a reference answer.")

    # 5. Requirement D: Internal assessment weightage cap (30 marks)
    if cat in ("quiz", "assignment", "project"):
        target_w = weightage if weightage is not None else 0.0
        current_internal_sum = 0.0
        for other in existing_assignments:
            if other.id == editing_assignment_id:
                continue
            c = (other.category or "assignment").lower()
            if c in ("quiz", "assignment", "project") and (other.status or "").lower() != "archived":
                current_internal_sum += (other.weightage or 0.0)
        if current_internal_sum + target_w > 30.01:
            raise ValueError("Internal assessment weightage cannot exceed 30 marks.")


class AssignmentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_assignments(self, course_id: int, status_filter: Optional[str] = None) -> List[Assignment]:
        query = select(Assignment).where(Assignment.course_id == course_id)
        if status_filter and status_filter != "all":
            query = query.where(Assignment.status == status_filter)
        query = query.order_by(Assignment.created_at.desc())
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def create_assignment(self, course_id: int, data: AssignmentCreate) -> Assignment:
        existing = await self.list_assignments(course_id)
        validate_assessment_rules(
            category=data.category,
            assignment_type=data.type,
            max_marks=data.max_marks,
            weightage=data.weightage,
            description=data.description,
            existing_assignments=existing,
            editing_assignment_id=None,
        )
        assignment = Assignment(
            course_id=course_id,
            title=data.title,
            description=data.description,
            type=data.type,
            category=data.category,
            weightage=data.weightage,
            max_marks=data.max_marks,
            deadline=data.deadline,
            allow_late=data.allow_late,
            late_penalty_per_day=data.late_penalty_per_day,
            max_penalty_cap=data.max_penalty_cap,
            time_limit_minutes=data.time_limit_minutes,
            max_attempts=data.max_attempts,
            randomize_questions=data.randomize_questions,
            show_results_after=data.show_results_after,
            status=AssignmentStatus.DRAFT.value,
        )
        self.db.add(assignment)
        await self.db.flush()


        # Link CLOs
        clo_ids_to_link = list(data.clo_ids or [])
        if not clo_ids_to_link:
            res = await self.db.execute(select(CLO).where(CLO.course_id == course_id).order_by(CLO.code))
            course_clos = list(res.scalars().all())
            if not course_clos:
                default_clo = CLO(
                    course_id=course_id,
                    code="CLO-1",
                    description="Understand and apply core course concepts and methodologies.",
                )
                self.db.add(default_clo)
                await self.db.flush()
                course_clos = [default_clo]
            clo_ids_to_link = [course_clos[0].id]

        for clo_id in clo_ids_to_link:
            await self.db.execute(
                assignment_clo_table.insert().values(assignment_id=assignment.id, clo_id=clo_id)
            )
        await self.db.flush()
        return await self.get_assignment(assignment.id)

    async def get_assignment(self, assignment_id: int) -> Assignment:
        result = await self.db.execute(
            select(Assignment)
            .options(
                selectinload(Assignment.clos),
                selectinload(Assignment.rubric).selectinload(Rubric.criteria),
                selectinload(Assignment.course),
            )
            .where(Assignment.id == assignment_id)
        )
        assignment = result.scalar_one_or_none()
        if not assignment:
            raise ValueError("Assignment not found.")
        return assignment

    async def delegated_ta_ids(self, assignment_id: int) -> set[int]:
        result = await self.db.execute(
            select(assignment_ta_table.c.user_id).where(
                assignment_ta_table.c.assignment_id == assignment_id
            )
        )
        return {row[0] for row in result.all()}

    async def delegated_ta_ids_for_user(self, course_id: int, user_id: int) -> set[int]:
        result = await self.db.execute(
            select(assignment_ta_table.c.assignment_id)
            .join(Assignment, Assignment.id == assignment_ta_table.c.assignment_id)
            .where(
                Assignment.course_id == course_id,
                assignment_ta_table.c.user_id == user_id,
            )
        )
        return {row[0] for row in result.all()}

    async def enrolled_student_ids(self, course_id: int) -> set[int]:
        result = await self.db.execute(
            select(Enrollment.user_id).where(
                Enrollment.course_id == course_id,
            )
        )
        return {row[0] for row in result.all()}

    async def verify_assignment_access(self, assignment_id: int, user: User) -> Assignment:
        assignment = await self.get_assignment(assignment_id)
        role = getattr(user.role, "value", user.role)
        enrolled_students = None
        if role == "student":
            enrolled_students = await self.enrolled_student_ids(assignment.course_id)
            if user.id not in enrolled_students:
                raise PermissionError("You are not enrolled in this course.")
            if (assignment.status or "").lower() == "draft":
                raise PermissionError("Assignment is not yet published.")
            return assignment

        if not can_access_assignment(
            user_role=user.role,
            user_id=user.id,
            assignment=assignment,
            delegated_ta_ids=await self.delegated_ta_ids(assignment_id),
            enrolled_student_ids=enrolled_students,
        ):
            raise PermissionError("You are not assigned to this assignment.")
        return assignment

    async def list_delegated_tas(self, assignment_id: int) -> list[dict]:
        result = await self.db.execute(
            select(User.id, User.full_name, User.email, assignment_ta_table.c.batch_size)
            .join(assignment_ta_table, assignment_ta_table.c.user_id == User.id)
            .where(assignment_ta_table.c.assignment_id == assignment_id)
            .order_by(User.full_name)
        )
        return [
            {
                "user_id": row.id,
                "user_name": row.full_name,
                "user_email": row.email,
                "batch_size": row.batch_size,
            }
            for row in result
        ]

    async def delegate_ta(self, assignment_id: int, ta_user_id: int) -> dict:
        assignment = await self.get_assignment(assignment_id)
        enrollment_result = await self.db.execute(
            select(Enrollment).where(
                Enrollment.course_id == assignment.course_id,
                Enrollment.user_id == ta_user_id,
                Enrollment.role == "ta",
            )
        )
        if not enrollment_result.scalar_one_or_none():
            raise ValueError("The user must be enrolled as a TA in this course first.")

        existing = await self.db.execute(
            select(assignment_ta_table.c.user_id).where(
                assignment_ta_table.c.assignment_id == assignment_id,
                assignment_ta_table.c.user_id == ta_user_id,
            )
        )
        if existing.first():
            raise ValueError("This TA is already assigned to the assignment.")

        await self.db.execute(
            assignment_ta_table.insert().values(
                assignment_id=assignment_id,
                user_id=ta_user_id,
                batch_size=None,
            )
        )
        await self.db.flush()
        return next(row for row in await self.list_delegated_tas(assignment_id) if row["user_id"] == ta_user_id)

    async def remove_ta(self, assignment_id: int, ta_user_id: int) -> None:
        result = await self.db.execute(
            delete(assignment_ta_table).where(
                assignment_ta_table.c.assignment_id == assignment_id,
                assignment_ta_table.c.user_id == ta_user_id,
            )
        )
        if result.rowcount == 0:
            raise ValueError("TA assignment not found.")
        await self.db.flush()

    async def update_assignment(self, assignment_id: int, data: AssignmentUpdate) -> Assignment:
        from fastapi import HTTPException
        from app.models.exam_attempt import ExamAttempt

        assignment = await self.get_assignment(assignment_id)
        update_data = data.model_dump(exclude_unset=True)

        # Check if attempts already exist
        if "time_limit_minutes" in update_data or "max_attempts" in update_data:
            att_check = await self.db.execute(
                select(ExamAttempt.id).where(ExamAttempt.assignment_id == assignment_id).limit(1)
            )
            if att_check.first():
                if "time_limit_minutes" in update_data and update_data["time_limit_minutes"] != assignment.time_limit_minutes:
                    raise HTTPException(
                        status_code=409,
                        detail="Cannot modify time limit: exam attempts have already commenced for this assignment.",
                    )
                if "max_attempts" in update_data and update_data["max_attempts"] != assignment.max_attempts:
                    raise HTTPException(
                        status_code=409,
                        detail="Cannot modify maximum attempts: exam attempts have already commenced for this assignment.",
                    )

        existing = await self.list_assignments(assignment.course_id)
        validate_assessment_rules(
            category=update_data.get("category", assignment.category),
            assignment_type=assignment.type,
            max_marks=update_data.get("max_marks", assignment.max_marks),
            weightage=update_data.get("weightage", assignment.weightage),
            description=update_data.get("description", assignment.description),
            existing_assignments=existing,
            editing_assignment_id=assignment.id,
        )

        clo_ids = update_data.pop("clo_ids", None)
        for key, value in update_data.items():
            setattr(assignment, key, value)
        if clo_ids is not None:
            await self.db.execute(
                assignment_clo_table.delete().where(assignment_clo_table.c.assignment_id == assignment_id)
            )
            for clo_id in clo_ids:
                await self.db.execute(
                    assignment_clo_table.insert().values(assignment_id=assignment_id, clo_id=clo_id)
                )
        await self.db.flush()
        return await self.get_assignment(assignment_id)

    async def publish_assignment(self, assignment_id: int) -> Assignment:
        """Publish with full HEC validation."""
        assignment = await self.get_assignment(assignment_id)
        errors = []

        # 1. Must have a rubric
        if not assignment.rubric:
            errors.append("A rubric is required before publishing.")
        else:
            criteria = assignment.rubric.criteria
            # 2. Min 3, max 10 criteria
            if len(criteria) < 3:
                errors.append(f"Rubric must have at least 3 criteria (currently {len(criteria)}).")
            if len(criteria) > 10:
                errors.append(f"Rubric must have at most 10 criteria (currently {len(criteria)}).")
            # 3. Weights must sum to 100
            total_weight = sum(c.weight for c in criteria)
            if abs(total_weight - 100.0) > 0.01:
                errors.append(f"Rubric weights must sum to 100 (currently {total_weight:.1f}).")
            # 4. Each criterion must have 4 levels
            for c in criteria:
                if len(c.levels) != 4:
                    errors.append(f"Criterion '{c.name}' must have exactly 4 levels (has {len(c.levels)}).")

        # 5. Must be linked to at least one CLO (auto-link if missing)
        if not assignment.clos:
            res = await self.db.execute(select(CLO).where(CLO.course_id == assignment.course_id).order_by(CLO.code))
            course_clos = list(res.scalars().all())
            if not course_clos:
                default_clo = CLO(
                    course_id=assignment.course_id,
                    code="CLO-1",
                    description="Understand and apply core course concepts and methodologies.",
                )
                self.db.add(default_clo)
                await self.db.flush()
                course_clos = [default_clo]
            await self.db.execute(
                assignment_clo_table.insert().values(assignment_id=assignment.id, clo_id=course_clos[0].id)
            )
            await self.db.flush()
            assignment = await self.get_assignment(assignment_id)

        # 6. Item 1.2: Block publishing an mcq/quiz assignment that has no parsed options
        atype = getattr(assignment, "type", "")
        atype_val = atype.value if hasattr(atype, "value") else str(atype)
        if atype_val in ("mcq", "quiz"):
            desc = assignment.description or ""
            has_options = False
            # Check JSON format
            if desc.strip().startswith("{") and desc.strip().endswith("}"):
                try:
                    import json
                    data = json.loads(desc)
                    questions = data.get("questions", [])
                    for q in questions:
                        opts = q.get("options", [])
                        if len(opts) >= 2:
                            has_options = True
                            break
                except Exception:
                    pass
            # Check text options A) B) or A. B.
            if not has_options:
                lines = desc.split("\n")
                opt_lines = [l.strip() for l in lines if re.match(r"^[A-Ea-e][\.\)]\s*", l.strip())]
                if len(opt_lines) >= 2:
                    has_options = True

            if not has_options:
                errors.append("MCQ assignment cannot be published without parsed options.")

        if errors:
            raise ValueError(" | ".join(errors))

        assignment.status = AssignmentStatus.PUBLISHED.value
        await self.db.flush()
        return assignment

    # ── Rubric CRUD ───────────────────────────────────

    async def get_rubric(self, assignment_id: int) -> Optional[Rubric]:
        result = await self.db.execute(
            select(Rubric).where(Rubric.assignment_id == assignment_id)
        )
        return result.scalar_one_or_none()

    async def create_or_update_rubric(self, assignment_id: int, data: RubricCreate) -> Rubric:
        # Delete existing rubric if any
        existing = await self.get_rubric(assignment_id)
        if existing:
            await self.db.delete(existing)
            await self.db.flush()

        rubric = Rubric(assignment_id=assignment_id)
        self.db.add(rubric)
        await self.db.flush()

        for idx, crit_data in enumerate(data.criteria):
            criterion = RubricCriterion(
                rubric_id=rubric.id, name=crit_data.name,
                weight=crit_data.weight, order=idx,
            )
            self.db.add(criterion)
            await self.db.flush()

            # Create all 4 levels
            if crit_data.levels:
                for level_data in crit_data.levels:
                    level = RubricLevel(
                        criterion_id=criterion.id,
                        level=level_data.level,
                        description=level_data.description,
                    )
                    self.db.add(level)
            else:
                # Auto-create empty 4 levels
                for level_name in LevelName:
                    level = RubricLevel(
                        criterion_id=criterion.id, level=level_name.value, description=""
                    )
                    self.db.add(level)
            await self.db.flush()

        # Reload
        return await self.get_rubric(assignment_id)
