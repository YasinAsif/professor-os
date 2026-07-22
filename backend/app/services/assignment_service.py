"""ProfessorOS – Assignment service (CRUD, HEC publish validation)."""

from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.assignment import Assignment, AssignmentStatus, assignment_clo_table
from app.models.course import CLO
from app.models.rubric import Rubric, RubricCriterion, RubricLevel, LevelName
from app.schemas.assignment import AssignmentCreate, AssignmentUpdate
from app.schemas.rubric import RubricCreate


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
        assignment = Assignment(
            course_id=course_id, title=data.title, description=data.description,
            type=data.type, max_marks=data.max_marks, deadline=data.deadline,
            allow_late=data.allow_late, late_penalty_per_day=data.late_penalty_per_day,
            max_penalty_cap=data.max_penalty_cap, status=AssignmentStatus.DRAFT.value,
        )
        self.db.add(assignment)
        await self.db.flush()

        # Link CLOs
        if data.clo_ids:
            for clo_id in data.clo_ids:
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
            )
            .where(Assignment.id == assignment_id)
        )
        assignment = result.scalar_one_or_none()
        if not assignment:
            raise ValueError("Assignment not found.")
        return assignment

    async def update_assignment(self, assignment_id: int, data: AssignmentUpdate) -> Assignment:
        assignment = await self.get_assignment(assignment_id)
        update_data = data.model_dump(exclude_unset=True)
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

        # 5. Must be linked to at least one CLO
        if not assignment.clos:
            errors.append("Assignment must be linked to at least one CLO.")

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
