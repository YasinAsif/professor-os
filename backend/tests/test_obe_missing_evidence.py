"""ProfessorOS – Verification that retired OBE/Bloom/Dossier endpoints & services are absent."""

import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


def test_retired_obe_services_are_decommissioned():
    """Verify decommissioned services cannot be imported."""
    with pytest.raises(ImportError):
        import app.services.blooms_gate  # noqa: F401

    with pytest.raises(ImportError):
        import app.services.question_generation  # noqa: F401

    with pytest.raises(ImportError):
        import app.services.clo_attainment  # noqa: F401

    with pytest.raises(ImportError):
        import app.services.hec_dossier  # noqa: F401


@pytest.mark.asyncio
async def test_retired_routes_return_404():
    """Verify removed routes are absent from FastAPI routing table."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. AI question generation endpoint
        res_gen = await client.post("/api/v1/quizzes/00000000-0000-0000-0000-000000000001/generate-questions", json={})
        assert res_gen.status_code == 404, f"Expected 404 for generate-questions, got {res_gen.status_code}"

        # 2. Bloom's Gate validation endpoint
        res_blooms = await client.get("/api/v1/quizzes/00000000-0000-0000-0000-000000000001/validate-blooms")
        assert res_blooms.status_code == 404, f"Expected 404 for validate-blooms, got {res_blooms.status_code}"

        # 3. CLO attainment endpoint
        res_clo = await client.get("/api/v1/courses/1/clo-attainment")
        assert res_clo.status_code == 404, f"Expected 404 for clo-attainment, got {res_clo.status_code}"

        # 4. HEC dossier download endpoint
        res_dossier = await client.get("/api/v1/courses/1/hec-dossier")
        assert res_dossier.status_code == 404, f"Expected 404 for hec-dossier, got {res_dossier.status_code}"
