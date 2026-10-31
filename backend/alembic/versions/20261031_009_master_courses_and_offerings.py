"""create master_courses table and add assessment category and weightage

Revision ID: 20261031_009
Revises: 20261027_008
Create Date: 2026-10-31 18:30:00.000000

"""
from typing import Sequence, Union
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa


revision: str = '20261031_009'
down_revision: Union[str, Sequence[str], None] = '20261027_008'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

CURRICULUM_COURSES = [
    # Semester 1.0
    ("Semester 1.0", "SEGC1112", "Applications of Information & Communication Technologies"),
    ("Semester 1.0", "SECC1123", "Programming Fundamentals"),
    ("Semester 1.0", "CSHU1113", "English composition & Comprehension"),
    ("Semester 1.0", "SEMC1003", "Remedial Mathematics-I"),
    ("Semester 1.0", "SEGC1111", "Applications of Information & Communication Technologies Lab"),
    ("Semester 1.0", "SECC1121", "Programming Fundamentals Lab"),
    ("Semester 1.0", "SEGC1133", "Discrete Structures"),

    # Semester 2.0
    ("Semester 2.0", "SECC1033", "Object Oriented Programming"),
    ("Semester 2.0", "SECC1031", "Object Oriented Programming Lab"),
    ("Semester 2.0", "SEMC1043", "Remedial Mathematics-II"),
    ("Semester 2.0", "SECC2123", "Database Systems"),
    ("Semester 2.0", "SECC2121", "Database Systems Lab"),
    ("Semester 2.0", "SECC1022", "Digital Logic Design"),
    ("Semester 2.0", "SECC1021", "Digital Logic Design Lab"),

    # Semester 3.0
    ("Semester 3.0", "AIGC1113", "Calculus & Analytic Geometry"),
    ("Semester 3.0", "SECC2113", "Data Structures"),
    ("Semester 3.0", "SECC2111", "Data Structures Lab"),
    ("Semester 3.0", "SECC4023", "Software Engineering"),
    ("Semester 3.0", "SECC2142", "Artificial Intelligence"),
    ("Semester 3.0", "SECC2141", "Artificial Intelligence Lab"),
    ("Semester 3.0", "SECC2032", "Computer Networks"),
    ("Semester 3.0", "SECC2031", "Computer Networks Lab"),
    ("Semester 3.0", "SECC1092", "Information Security"),
    ("Semester 3.0", "SECC1091", "Information Security Lab"),

    # Semester 4.0
    ("Semester 4.0", "SEGC1013", "Expository Writing"),
    ("Semester 4.0", "CYMC1023", "Multivariable Calculus"),
    ("Semester 4.0", "CYCC2182", "Computer Organization & Assembly Language"),
    ("Semester 4.0", "SECC2151", "Computer Organization & Assembly Language Lab"),
    ("Semester 4.0", "SEDC2102", "Software Requirement Engineering"),
    ("Semester 4.0", "SEDC2101", "Software Requirement Engineering Lab"),
    ("Semester 4.0", "SEEC3092", "Object Oriented Analysis and Design"),
    ("Semester 4.0", "SEEC3091", "Object Oriented Analysis and Design Lab"),
    ("Semester 4.0", "SEGC1122", "Applied Physics"),
    ("Semester 4.0", "SEGC1121", "Applied Physics Lab"),

    # Semester 5.0
    ("Semester 5.0", "SEGC1022", "Introduction to Management"),
    ("Semester 5.0", "SECC3122", "Operating Systems"),
    ("Semester 5.0", "SEMC2023", "Linear Algebra"),
    ("Semester 5.0", "SECC3121", "Operating Systems Lab"),
    ("Semester 5.0", "SEDC3113", "Software Design & Architecture"),
    ("Semester 5.0", "SEDC3033", "Software Engineering II"),
    ("Semester 5.0", "SEDC3031", "Software Quality Engineering Lab"),
    ("Semester 5.0", "SEEC3112", "Web Technologies"),
    ("Semester 5.0", "SEEC3111", "Web Technologies Lab"),
    ("Semester 5.0", "SEEC3102", "HCI & Computer Graphics"),
    ("Semester 5.0", "SEEC3101", "HCI & Computer Graphics Lab"),

    # Semester 6.0
    ("Semester 6.0", "AIMC1023", "Probability & Statistics"),
    ("Semester 6.0", "SESC2083", "Introduction to Marketing"),
    ("Semester 6.0", "SEDC2111", "Software Construction & Development Lab"),
    ("Semester 6.0", "SEDC2112", "Software Construction & Development"),
    ("Semester 6.0", "SEEC3223", "Machine Learning"),
    ("Semester 6.0", "SEEC3221", "Machine Learning Lab"),
    ("Semester 6.0", "SEDC3052", "Parallel & Distributed Computing"),
    ("Semester 6.0", "SEEC4103", "DevOps for Cloud Computing"),
    ("Semester 6.0", "CSEC3093", "Mobile Application Development"),
    ("Semester 6.0", "CSEC3091", "Mobile Application Development Lab"),
    ("Semester 6.0", "SEDC3051", "Parallel & Distributed Computing Lab"),

    # Semester 7.0
    ("Semester 7.0", "SEMC3022", "Technical & Business Writing"),
    ("Semester 7.0", "SEGC4122", "Islamic Studies"),
    ("Semester 7.0", "SECC4113", "Final Year Project-I"),
    ("Semester 7.0", "SECC2063", "Analysis of Algorithms"),
    ("Semester 7.0", "SEDC3112", "Software Project Management"),
    ("Semester 7.0", "SEDC3111", "Software Project Management Lab"),
    ("Semester 7.0", "CYGC4162", "Entrepreneurship"),
    ("Semester 7.0", "SEEC4092", "Software Verification and Validation"),
    ("Semester 7.0", "SEEC4091", "Software Verification and Validation Lab"),
]

ADDITIONAL_COURSES = [
    ("Spring 2027", "CS-505", "Distributed Cloud Systems & AI Architecture"),
    ("Spring-2026", "CS301", "Advanced Operating Systems"),
    ("Browser Tests", "E2E101", "Browser E2E Course"),
    ("fall2023", "CS11", "Test1"),
    ("2027", "TEST2", "test"),
]


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    # 1. Create master_courses table
    if "master_courses" not in tables:
        op.create_table(
            "master_courses",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("code", sa.String(length=20), nullable=False),
            sa.Column("title", sa.String(length=255), nullable=False),
            sa.Column("department", sa.String(length=100), nullable=True, server_default="Computer Science"),
            sa.Column("semester", sa.String(length=50), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("code", name="uq_master_courses_code"),
            sa.UniqueConstraint("title", name="uq_master_courses_title"),
        )
        op.create_index(op.f("ix_master_courses_code"), "master_courses", ["code"], unique=True)

    # 2. Add columns to courses table
    course_columns = [col["name"] for col in inspector.get_columns("courses")]
    if "master_course_id" not in course_columns:
        op.add_column("courses", sa.Column("master_course_id", sa.Integer(), nullable=True))
        op.create_foreign_key(
            "fk_courses_master_course_id", "courses", "master_courses", ["master_course_id"], ["id"], ondelete="SET NULL"
        )
        op.create_index(op.f("ix_courses_master_course_id"), "courses", ["master_course_id"], unique=False)

    if "section" not in course_columns:
        op.add_column("courses", sa.Column("section", sa.String(length=50), nullable=True, server_default="Section A"))

    # 3. Add category and weightage columns to assignments table
    assignment_columns = [col["name"] for col in inspector.get_columns("assignments")]
    if "category" not in assignment_columns:
        op.add_column("assignments", sa.Column("category", sa.String(length=50), nullable=True, server_default="assignment"))
        op.create_index(op.f("ix_assignments_category"), "assignments", ["category"], unique=False)

    if "weightage" not in assignment_columns:
        op.add_column("assignments", sa.Column("weightage", sa.Float(), nullable=True, server_default="0.0"))

    # 4. Seed master_courses data
    master_courses_table = sa.table(
        "master_courses",
        sa.column("id", sa.Integer),
        sa.column("code", sa.String),
        sa.column("title", sa.String),
        sa.column("department", sa.String),
        sa.column("semester", sa.String),
        sa.column("created_at", sa.DateTime),
    )

    now = datetime.now(timezone.utc)
    seen_codes = set()
    seen_titles = set()

    for sem, code, title in CURRICULUM_COURSES + ADDITIONAL_COURSES:
        code_u = code.strip().upper()
        title_u = title.strip()
        if code_u in seen_codes or title_u in seen_titles:
            continue
        seen_codes.add(code_u)
        seen_titles.add(title_u)
        
        # Check if already present in table
        exists = bind.execute(
            sa.text("SELECT id FROM master_courses WHERE UPPER(code) = :c OR UPPER(title) = :t"),
            {"c": code_u, "t": title_u.upper()}
        ).scalar()
        if not exists:
            bind.execute(
                sa.text("""
                    INSERT INTO master_courses (code, title, department, semester, created_at)
                    VALUES (:code, :title, 'Computer Science', :sem, :created_at)
                """),
                {"code": code_u, "title": title_u, "sem": sem, "created_at": now}
            )

    # 5. Backfill courses.master_course_id
    bind.execute(sa.text("""
        UPDATE courses c
        SET master_course_id = mc.id
        FROM master_courses mc
        WHERE UPPER(c.code) = UPPER(mc.code)
          AND c.master_course_id IS NULL
    """))

    # 6. Archive 7 duplicate CS-505 courses (keep id 74 as active)
    bind.execute(sa.text("""
        UPDATE courses
        SET is_archived = TRUE
        WHERE code = 'CS-505' AND id > 74
    """))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if "assignments" in tables:
        assignment_columns = [col["name"] for col in inspector.get_columns("assignments")]
        if "weightage" in assignment_columns:
            op.drop_column("assignments", "weightage")
        if "category" in assignment_columns:
            op.drop_index(op.f("ix_assignments_category"), table_name="assignments")
            op.drop_column("assignments", "category")

    if "courses" in tables:
        course_columns = [col["name"] for col in inspector.get_columns("courses")]
        if "section" in course_columns:
            op.drop_column("courses", "section")
        if "master_course_id" in course_columns:
            op.drop_constraint("fk_courses_master_course_id", "courses", type_="foreignkey")
            op.drop_index(op.f("ix_courses_master_course_id"), table_name="courses")
            op.drop_column("courses", "master_course_id")

    if "master_courses" in tables:
        op.drop_table("master_courses")
