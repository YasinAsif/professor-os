"""ProfessorOS – User management service (admin CSV import, status changes)."""

import csv
import io
from typing import List, Optional

from sqlalchemy import func, select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.user import User
from app.schemas.user import CSVImportResult


class UserService:
    """Handles admin user management operations."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_users(
        self,
        page: int = 1,
        page_size: int = 20,
        role_filter: Optional[str] = None,
        search: Optional[str] = None,
    ):
        """Paginated user list with optional filters."""
        query = select(User)

        if role_filter and role_filter != "all":
            query = query.where(User.role == role_filter)

        if search:
            pattern = f"%{search}%"
            query = query.where(
                or_(
                    User.full_name.ilike(pattern),
                    User.email.ilike(pattern),
                )
            )

        # Get total count
        count_q = select(func.count()).select_from(query.subquery())
        total = (await self.db.execute(count_q)).scalar() or 0

        # Paginate
        query = query.offset((page - 1) * page_size).limit(page_size).order_by(User.created_at.desc())
        result = await self.db.execute(query)
        users = list(result.scalars().all())

        return users, total

    async def import_csv(self, file_content: bytes) -> CSVImportResult:
        """
        Import users from a CSV file.
        Expected columns: email, full_name, role, password
        Duplicate emails are reported as errors (NOT silently skipped).
        """
        created = 0
        skipped = 0
        errors: List[dict] = []

        text = file_content.decode("utf-8-sig")  # Handle BOM
        reader = csv.DictReader(io.StringIO(text))

        for row_num, row in enumerate(reader, start=2):  # Start at 2 (header is row 1)
            email = (row.get("email") or "").strip().lower()
            full_name = (row.get("full_name") or "").strip()
            role = (row.get("role") or "student").strip().lower()
            password = (row.get("password") or "").strip()

            # Validate required fields
            if not email:
                errors.append({"row": row_num, "email": "", "reason": "Email is required."})
                continue
            if not full_name:
                errors.append({"row": row_num, "email": email, "reason": "Full name is required."})
                continue
            if not password or len(password) < 8:
                errors.append({"row": row_num, "email": email, "reason": "Password must be at least 8 characters."})
                continue
            if role not in ("professor", "student", "ta", "admin"):
                errors.append({"row": row_num, "email": email, "reason": f"Invalid role: {role}"})
                continue

            # Check for duplicate email
            existing = await self.db.execute(
                select(User).where(User.email == email)
            )
            if existing.scalar_one_or_none():
                errors.append({"row": row_num, "email": email, "reason": "Duplicate email – account already exists."})
                continue

            # Create user
            user = User(
                email=email,
                full_name=full_name,
                hashed_password=hash_password(password),
                role=role,
                is_verified=True,  # CSV-imported users are pre-verified
                is_active=True,
            )
            self.db.add(user)
            created += 1

        await self.db.flush()
        return CSVImportResult(created=created, skipped=skipped, errors=errors)

    async def update_status(self, user_id: int, is_active: bool) -> User:
        """Suspend or unsuspend a user."""
        user = await self.db.get(User, user_id)
        if not user:
            raise ValueError("User not found.")
        user.is_active = is_active
        await self.db.flush()
        return user

    async def delete_user(self, user_id: int) -> None:
        """Delete a user permanently."""
        user = await self.db.get(User, user_id)
        if not user:
            raise ValueError("User not found.")
        await self.db.delete(user)
        await self.db.flush()
