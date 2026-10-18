import asyncio
import asyncpg
import json
import os

async def main():
    try:
        conn = await asyncpg.connect("postgresql://postgres:postgres@localhost:5432/professor_os")
        print("Connected to PostgreSQL professor_os database successfully.")
        
        # Get list of all tables
        tables = await conn.fetch("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        table_names = [r["table_name"] for r in tables]
        print(f"Total tables: {len(table_names)}")
        
        # Create a backup directory and backup each table as JSON
        os.makedirs("backups", exist_ok=True)
        backup_file = "backups/dev_db_backup.json"
        db_dump = {}
        for t in table_names:
            rows = await conn.fetch(f'SELECT * FROM "{t}"')
            db_dump[t] = [dict(r) for r in rows]
            # Convert datetime/UUID/bytes to str
            for row in db_dump[t]:
                for k, v in row.items():
                    if hasattr(v, "isoformat"):
                        row[k] = v.isoformat()
                    elif isinstance(v, (bytes, bytearray)):
                        row[k] = str(v)
        
        with open(backup_file, "w", encoding="utf-8") as f:
            json.dump(db_dump, f, indent=2, default=str)
        print(f"Database backed up successfully to {backup_file}.")
        await conn.close()
    except Exception as e:
        print(f"PostgreSQL connection error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
