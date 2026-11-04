"""normalize_mcq_options_and_assignment_descriptions

Revision ID: 20261104_010
Revises: 20261031_009
Create Date: 2026-11-04 07:35:00.000000

"""
from typing import Sequence, Union
import json
from alembic import op
import sqlalchemy as sa


revision: str = '20261104_010'
down_revision: Union[str, Sequence[str], None] = '20261031_009'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()

    # 1. Normalize question_bank options
    qb_rows = conn.execute(
        sa.text("SELECT question_id, options, correct_answer FROM question_bank WHERE options IS NOT NULL")
    ).fetchall()

    for q_id, options, correct_ans in qb_rows:
        if not options:
            continue
        parsed_opts = options
        if isinstance(options, str):
            try:
                parsed_opts = json.loads(options)
            except Exception:
                continue

        if isinstance(parsed_opts, list):
            clean_opts = []
            found_correct = None
            modified = False

            for opt in parsed_opts:
                if isinstance(opt, dict):
                    modified = True
                    text = opt.get("text") or opt.get("option") or opt.get("label") or opt.get("value") or str(opt)
                    clean_opts.append(str(text).strip())
                    if opt.get("is_correct") is True and not found_correct:
                        found_correct = str(text).strip()
                else:
                    clean_opts.append(str(opt).strip())

            if modified:
                new_ans = found_correct or correct_ans
                conn.execute(
                    sa.text(
                        "UPDATE question_bank SET options = :opts::jsonb, correct_answer = :ans WHERE question_id = :qid"
                    ),
                    {"opts": json.dumps(clean_opts), "ans": new_ans, "qid": q_id},
                )

    # 2. Normalize assignments description if stored as JSON
    assign_rows = conn.execute(
        sa.text("SELECT id, description FROM assignments WHERE description IS NOT NULL AND description LIKE '{%}'")
    ).fetchall()

    for aid, desc in assign_rows:
        if not desc or not desc.strip().startswith("{"):
            continue
        try:
            data = json.loads(desc)
            if not isinstance(data, dict):
                continue
            questions = data.get("questions")
            if not isinstance(questions, list):
                continue

            modified = False
            for q in questions:
                if isinstance(q, dict) and "options" in q and isinstance(q["options"], list):
                    clean_opts = []
                    found_correct_idx = None
                    for idx, opt in enumerate(q["options"]):
                        if isinstance(opt, dict):
                            modified = True
                            text = opt.get("text") or opt.get("option") or opt.get("label") or str(opt)
                            clean_opts.append(str(text).strip())
                            if opt.get("is_correct") is True and found_correct_idx is None:
                                found_correct_idx = idx
                        else:
                            clean_opts.append(str(opt).strip())
                    q["options"] = clean_opts
                    if found_correct_idx is not None and "correct" not in q:
                        q["correct"] = found_correct_idx

            if modified:
                conn.execute(
                    sa.text("UPDATE assignments SET description = :new_desc WHERE id = :aid"),
                    {"new_desc": json.dumps(data), "aid": aid},
                )
        except Exception:
            continue


def downgrade() -> None:
    pass
