"""ProfessorOS – User management service (admin CSV import, status changes)."""

import csv
import io
import asyncio
from typing import List, Optional

from sqlalchemy import func, select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.user import User
from app.schemas.user import CSVImportResult
from app.services.email_service import send_approval_email, send_rejection_email


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

    async def create_user_by_admin(self, email: str, full_name: str, role: str, password: str) -> User:
        """Manually create a single user by Admin."""
        clean_email = email.strip().lower()
        existing = await self.db.execute(select(User).where(User.email == clean_email))
        if existing.scalar_one_or_none():
            raise ValueError(f"User with email '{clean_email}' already exists.")

        user = User(
            email=clean_email,
            full_name=full_name.strip(),
            hashed_password=hash_password(password),
            role=role.strip().lower(),
            is_verified=True,
            is_active=True,
        )
        self.db.add(user)
        await self.db.flush()
        return user

    async def update_user_role(self, user_id: int, new_role: str) -> User:
        """Update user role."""
        if new_role not in ("professor", "student", "ta", "admin"):
            raise ValueError(f"Invalid role: {new_role}")
        user = await self.db.get(User, user_id)
        if not user:
            raise ValueError("User not found.")
        user.role = new_role
        await self.db.flush()
        return user

    async def admin_reset_password(self, user_id: int, new_password: str) -> User:
        """Admin force reset user password."""
        user = await self.db.get(User, user_id)
        if not user:
            raise ValueError("User not found.")
        user.hashed_password = hash_password(new_password)
        await self.db.flush()
        return user

    async def list_pending_users(self) -> List[User]:
        """List users awaiting admin approval."""
        result = await self.db.execute(
            select(User).where(User.is_approved.is_(False)).order_by(User.created_at.desc())
        )
        return list(result.scalars().all())

    async def approve_user(self, user_id: int) -> User:
        """Approve a pending user signup."""
        user = await self.db.get(User, user_id)
        if not user:
            raise ValueError("User not found.")
        if user.is_approved:
            raise ValueError("User is already approved.")
        user.is_approved = True
        await self.db.flush()
        await asyncio.to_thread(send_approval_email, user.email, user.full_name, user.role)
        return user

    async def reject_user(self, user_id: int, reason: str | None = None) -> None:
        """Reject and delete a pending user signup."""
        user = await self.db.get(User, user_id)
        if not user:
            raise ValueError("User not found.")
        email, full_name, role = user.email, user.full_name, user.role
        await self.db.delete(user)
        await self.db.flush()
        await asyncio.to_thread(send_rejection_email, email, full_name, role, reason)

    async def get_user_stats(self) -> dict:
        """Get aggregate counts of users by role and status."""
        total_q = select(func.count(User.id))
        total = (await self.db.execute(total_q)).scalar() or 0

        active_q = select(func.count(User.id)).where(User.is_active.is_(True))
        active = (await self.db.execute(active_q)).scalar() or 0
        inactive = total - active

        roles = ["professor", "student", "ta", "admin"]
        role_counts = {}
        for r in roles:
            rq = select(func.count(User.id)).where(User.role == r)
            role_counts[r] = (await self.db.execute(rq)).scalar() or 0

        pending_q = select(func.count(User.id)).where(User.is_approved.is_(False))
        pending = (await self.db.execute(pending_q)).scalar() or 0

        return {
            "total_users": total,
            "active_users": active,
            "inactive_users": inactive,
            "pending_approvals": pending,
            "role_counts": role_counts,
        }

    async def export_users_csv(self, role_filter: Optional[str] = None, search: Optional[str] = None) -> str:
        """Export filtered users list as CSV string."""
        users, _ = await self.list_users(page=1, page_size=10000, role_filter=role_filter, search=search)
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["id", "email", "full_name", "role", "is_active", "is_verified", "created_at"])
        for u in users:
            writer.writerow([
                u.id, u.email, u.full_name, u.role, u.is_active, u.is_verified,
                u.created_at.isoformat() if u.created_at else ""
            ])
        return output.getvalue()
