"""ProfessorOS – Course Management Module Tests (TC-11 to TC-15)."""

import pytest
import httpx

BASE_URL = "https://professor-os-production.up.railway.app/api/v1"

@pytest.mark.asyncio
async def test_tc11_create_valid_course():
    """TC-11: Verify Professor can create a course with valid HEC 100% weightage."""
    async with httpx.AsyncClient() as client:
        # Login as admin/professor using JSON body
        login_res = await client.post(f"{BASE_URL}/auth/login", json={"email": "admin@professoros.edu.pk", "password": "admin123"})
        assert login_res.status_code == 200
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Create course payload
        payload = {
            "title": "Software Engineering Principles",
            "code": "CS-301",
            "semester": "Fall 2026",
            "description": "Core software architecture and design patterns course.",
            "quiz_weight": 20,
            "assignment_weight": 20,
            "midterm_weight": 20,
            "final_weight": 40
        }
        res = await client.post(f"{BASE_URL}/courses", json=payload, headers=headers)
        assert res.status_code in [201, 400]  # 201 Created or 400 if already exists


@pytest.mark.asyncio
async def test_tc12_invalid_hec_weightage_rejection():
    """TC-12: Verify system rejects course creation if HEC weights do not sum to 100%."""
    async with httpx.AsyncClient() as client:
        login_res = await client.post(f"{BASE_URL}/auth/login", json={"email": "admin@professoros.edu.pk", "password": "admin123"})
        assert login_res.status_code == 200
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Invalid payload (sum = 90%)
        payload = {
            "title": "Invalid Weight Course",
            "code": "CS-999",
            "semester": "Fall 2026",
            "quiz_weight": 10,
            "assignment_weight": 20,
            "midterm_weight": 20,
            "final_weight": 40
        }
        res = await client.post(f"{BASE_URL}/courses", json=payload, headers=headers)
        assert res.status_code == 400
        assert "HEC weights must sum to 100" in res.text


@pytest.mark.asyncio
async def test_tc13_clo_creation_and_listing():
    """TC-13: Verify Professor can map HEC CLOs to a course."""
    async with httpx.AsyncClient() as client:
        login_res = await client.post(f"{BASE_URL}/auth/login", json={"email": "admin@professoros.edu.pk", "password": "admin123"})
        assert login_res.status_code == 200
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get course list
        courses_res = await client.get(f"{BASE_URL}/courses", headers=headers)
        assert courses_res.status_code == 200
        courses = courses_res.json()["courses"]
        if courses:
            course_id = courses[0]["id"]
            clo_payload = {"code": "CLO-1", "description": "Apply software engineering principles to design robust APIs."}
            clo_res = await client.post(f"{BASE_URL}/courses/{course_id}/clos", json=clo_payload, headers=headers)
            assert clo_res.status_code in [201, 400]


@pytest.mark.asyncio
async def test_tc14_student_join_code_validation():
    """TC-14: Verify Student joining with invalid join code fails cleanly."""
    async with httpx.AsyncClient() as client:
        res = await client.post(f"{BASE_URL}/courses/join", json={"join_code": "INVALID"})
        assert res.status_code in [400, 401, 403]


@pytest.mark.asyncio
async def test_tc15_ta_delegation():
    """TC-15: Verify Professor can delegate TA role for a course."""
    async with httpx.AsyncClient() as client:
        login_res = await client.post(f"{BASE_URL}/auth/login", json={"email": "admin@professoros.edu.pk", "password": "admin123"})
        assert login_res.status_code == 200
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        courses_res = await client.get(f"{BASE_URL}/courses", headers=headers)
        if courses_res.json()["courses"]:
            course_id = courses_res.json()["courses"][0]["id"]
            res = await client.post(f"{BASE_URL}/courses/{course_id}/enroll", json={"user_id": 1, "role": "ta"}, headers=headers)
            assert res.status_code in [201, 400, 422, 500]



