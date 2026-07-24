import asyncio
import os
import sys

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy import text

async def main():
    db_url = os.environ.get("DATABASE_URL", "postgresql+asyncpg://postgres:admin@127.0.0.1:5432/professor_os_db")
    print(f"Connecting to {db_url}...")
    engine = create_async_engine(db_url)
    
    async with AsyncSession(engine) as session:
        # Check if user exists
        result = await session.execute(text("SELECT email, role FROM users WHERE email = 'impossiblehistorian@gmail.com'"))
        user = result.fetchone()
        
        if user:
            print(f"Found user: {user.email}, current role: {user.role}")
            await session.execute(text("UPDATE users SET role = 'ta' WHERE email = 'impossiblehistorian@gmail.com'"))
            await session.commit()
            print("Successfully updated role to 'ta'!")
        else:
            print("User 'impossiblehistorian@gmail.com' not found in database.")

if __name__ == "__main__":
    asyncio.run(main())
