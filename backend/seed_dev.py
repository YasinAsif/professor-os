import asyncio
from app.db.base import async_session
from app.models import user, course, assignment, rubric, analytics  # noqa: F401
from app.models.user import User, UserRole
from app.core.security import hash_password
from sqlalchemy import select

async def seed_users():
    async with async_session() as session:
        # Check prof@example.com
        res = await session.execute(select(User).where(User.email == "prof@example.com"))
        prof = res.scalar_one_or_none()
        if not prof:
            prof = User(
                email="prof@example.com",
                full_name="Dr. Yasin (Professor)",
                hashed_password=hash_password("password123"),
                role=UserRole.PROFESSOR.value,
                is_active=True,
                is_verified=True,
            )
            session.add(prof)
            print("Seeded professor: prof@example.com / password123")

        # Check student@example.com
        res_stud = await session.execute(select(User).where(User.email == "student@example.com"))
        stud = res_stud.scalar_one_or_none()
        if not stud:
            stud = User(
                email="student@example.com",
                full_name="Ali Student",
                hashed_password=hash_password("password123"),
                role=UserRole.STUDENT.value,
                is_active=True,
                is_verified=True,
            )
            session.add(stud)
        # Check ta@example.com
        res_ta = await session.execute(select(User).where(User.email == "ta@example.com"))
        ta = res_ta.scalar_one_or_none()
        if not ta:
            ta = User(
                email="ta@example.com",
                full_name="Tariq TA",
                hashed_password=hash_password("password123"),
                role=UserRole.TA.value,
                is_active=True,
                is_verified=True,
            )
            session.add(ta)
            print("Seeded TA: ta@example.com / password123")

        # Check admin@professoros.edu.pk
        res_admin = await session.execute(select(User).where(User.email == "admin@professoros.edu.pk"))
        admin = res_admin.scalar_one_or_none()
        if not admin:
            admin = User(
                email="admin@professoros.edu.pk",
                full_name="System Administrator",
                hashed_password=hash_password("password123"),
                role=UserRole.ADMIN.value,
                is_active=True,
                is_verified=True,
                is_approved=True,
            )
            session.add(admin)
            print("Seeded admin: admin@professoros.edu.pk / password123")
        else:
            admin.role = UserRole.ADMIN.value
            admin.is_active = True
            admin.is_verified = True
            admin.is_approved = True
            admin.failed_attempts = 0
            admin.locked_until = None
            admin.hashed_password = hash_password("password123")
            print("Updated admin: admin@professoros.edu.pk / password123")

        # Check admin@example.com
        res_admin2 = await session.execute(select(User).where(User.email == "admin@example.com"))
        admin2 = res_admin2.scalar_one_or_none()
        if not admin2:
            admin2 = User(
                email="admin@example.com",
                full_name="System Administrator",
                hashed_password=hash_password("password123"),
                role=UserRole.ADMIN.value,
                is_active=True,
                is_verified=True,
                is_approved=True,
            )
            session.add(admin2)
            print("Seeded admin: admin@example.com / password123")
        else:
            admin2.role = UserRole.ADMIN.value
            admin2.is_active = True
            admin2.is_verified = True
            admin2.is_approved = True
            admin2.failed_attempts = 0
            admin2.locked_until = None
            admin2.hashed_password = hash_password("password123")
            print("Updated admin: admin@example.com / password123")

        await session.commit()

if __name__ == "__main__":
    asyncio.run(seed_users())
