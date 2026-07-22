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

        await session.commit()

if __name__ == "__main__":
    asyncio.run(seed_users())
