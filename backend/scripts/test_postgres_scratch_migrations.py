"""ProfessorOS - Test migrations 005 and 006 upgrade and downgrade on scratch PostgreSQL database.
"""

import asyncio
import os
import sys
import asyncpg
from alembic.config import Config
from alembic import command


SCRATCH_DB_NAME = "professor_os_scratch_migration_test"
PG_BASE_URL = "postgresql://postgres:postgres@localhost:5432/postgres"
PG_SCRATCH_URL_SYNC = f"postgresql://postgres:postgres@localhost:5432/{SCRATCH_DB_NAME}"


async def setup_scratch_db():
    print(f"[1/6] Connecting to PostgreSQL at {PG_BASE_URL}...")
    sys_conn = await asyncpg.connect(PG_BASE_URL)
    try:
        print(f"[2/6] Dropping scratch database '{SCRATCH_DB_NAME}' if exists...")
        # Terminate any existing connections to scratch DB
        await sys_conn.execute(f"""
            SELECT pg_terminate_backend(pg_stat_activity.pid)
            FROM pg_stat_activity
            WHERE pg_stat_activity.datname = '{SCRATCH_DB_NAME}'
              AND pid <> pg_backend_pid();
        """)
        await sys_conn.execute(f"DROP DATABASE IF EXISTS {SCRATCH_DB_NAME};")
        print(f"[3/6] Creating scratch database '{SCRATCH_DB_NAME}'...")
        await sys_conn.execute(f"CREATE DATABASE {SCRATCH_DB_NAME};")
    finally:
        await sys_conn.close()
    print("Scratch database created successfully.")


def run_alembic_migrations():
    alembic_ini_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "alembic.ini")
    cfg = Config(alembic_ini_path)
    cfg.set_main_option("sqlalchemy.url", PG_SCRATCH_URL_SYNC)

    print(f"[4/6] Running baseline migrations up to 20261014_004 on '{SCRATCH_DB_NAME}'...")
    command.upgrade(cfg, "20261014_004")
    print(" -> Baseline schema (20261014_004) successfully created on PostgreSQL.")

    print("\n>>> Testing MIGRATION 005 UPGRADE...")
    command.upgrade(cfg, "20261017_005")
    print(" -> 20261017_005 UPGRADE SUCCESSFUL on PostgreSQL.")

    print("\n>>> Testing MIGRATION 006 UPGRADE...")
    command.upgrade(cfg, "20261017_006")
    print(" -> 20261017_006 UPGRADE SUCCESSFUL on PostgreSQL.")

    print("\n>>> Testing MIGRATION 006 DOWNGRADE (to 005)...")
    command.downgrade(cfg, "20261017_005")
    print(" -> 20261017_006 DOWNGRADE SUCCESSFUL on PostgreSQL.")

    print("\n>>> Testing MIGRATION 005 DOWNGRADE (to 004)...")
    command.downgrade(cfg, "20261014_004")
    print(" -> 20261017_005 DOWNGRADE SUCCESSFUL on PostgreSQL.")

    print("\n>>> Testing RE-UPGRADE TO HEAD...")
    command.upgrade(cfg, "head")
    print(" -> RE-UPGRADE TO HEAD SUCCESSFUL on PostgreSQL.")


async def teardown_scratch_db():
    print(f"\n[5/6] Cleaning up scratch database '{SCRATCH_DB_NAME}'...")
    sys_conn = await asyncpg.connect(PG_BASE_URL)
    try:
        await sys_conn.execute(f"""
            SELECT pg_terminate_backend(pg_stat_activity.pid)
            FROM pg_stat_activity
            WHERE pg_stat_activity.datname = '{SCRATCH_DB_NAME}'
              AND pid <> pg_backend_pid();
        """)
        await sys_conn.execute(f"DROP DATABASE IF EXISTS {SCRATCH_DB_NAME};")
    finally:
        await sys_conn.close()
    print("[6/6] Scratch database dropped. Dev database was never touched.")


def main():
    asyncio.run(setup_scratch_db())
    try:
        run_alembic_migrations()
    finally:
        asyncio.run(teardown_scratch_db())
    print("\n=== ALL POSTGRESQL MIGRATION TESTS PASSED ===")


if __name__ == "__main__":
    main()
