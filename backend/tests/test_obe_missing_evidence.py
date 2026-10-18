from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.clo_attainment import compute_and_record_attainment
from app.services.hec_dossier import generate_dossier_html


class QueryResult:
    def __init__(self, rows=(), first=None):
        self._rows = rows
        self._first = first

    def mappings(self):
        return self

    def all(self):
        return self._rows

    def first(self):
        return self._first


@pytest.mark.asyncio
async def test_missing_attempts_are_not_recorded_as_attainment():
    clo = {
        "clo_id": "da2bfaf1-006a-46d4-89e1-7bca622c741d",
        "code": "CLO-1",
        "description": "Apply core concepts",
        "bloom_target_level": "C3",
    }
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                QueryResult(rows=[clo]),
                QueryResult(first={"total_students": 0, "attained_students": 0}),
            ]
        ),
        commit=AsyncMock(),
    )

    report = await compute_and_record_attainment(7, "Spring-2026", db)

    assert report.overall_obe_compliance_status == "INSUFFICIENT_EVIDENCE"
    assert report.clos[0].cohort_size == 0
    assert report.clos[0].attainment_percentage == 0
    assert db.execute.await_count == 2  # CLO lookup + score lookup; no fake record
    db.commit.assert_awaited_once()


def test_dossier_does_not_claim_compliance_without_clos_or_evidence():
    html = generate_dossier_html(
        course={"code": "TEST-1", "title": "Test Course"},
        semester="Spring-2026",
        clos=[],
        bloom_counts={"C1": 0, "C2": 0, "C3": 0, "C4": 0, "C5": 0, "C6": 0},
        overall_status="INSUFFICIENT_EVIDENCE",
    )

    assert "INSUFFICIENT EVIDENCE" in html
    assert "Insufficient evidence" in html
    assert "OBE COMPLIANT" not in html
    assert "CLO-1" not in html
