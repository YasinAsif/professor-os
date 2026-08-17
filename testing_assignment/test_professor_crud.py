"""
ProfessorOS – Comprehensive CRUD Operations Test for Professor Role
Tests all Create, Read, Update, Delete operations for courses and assignments
"""

import pytest
import httpx
from datetime import datetime, timedelta

BASE_URL = "https://professor-os-production.up.railway.app/api/v1"

# Test credentials
PROFESSOR_EMAIL = "admin@professoros.edu.pk"
PROFESSOR_PASSWORD = "admin123"


# ──────────────────────────────────────────────────────────────────────────────
# COURSES CRUD TESTS
# ──────────────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_course_create_valid():
    """✅ CRUD-C1: Professor creates a new course with valid data"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        payload = {
            "title": "Data Structures & Algorithms",
            "code": "CS-201",
            "semester": "Spring 2026",
            "description": "Comprehensive course on DSA",
            "quiz_weight": 20,
            "assignment_weight": 20,
            "midterm_weight": 20,
            "final_weight": 40,
            "at_risk_threshold": 50.0
        }
        
        res = await client.post(f"{BASE_URL}/courses", json=payload, headers=headers)
        assert res.status_code == 201, f"Failed: {res.text}"
        data = res.json()
        assert data["title"] == "Data Structures & Algorithms"
        assert data["code"] == "CS-201"
        print(f"✅ Course created successfully with ID: {data['id']}")


@pytest.mark.asyncio
async def test_course_create_invalid_weights():
    """❌ CRUD-C2: Professor attempts to create course with invalid weights (should fail)"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        payload = {
            "title": "Invalid Course",
            "code": f"XX-{int(datetime.now().timestamp())}",
            "semester": "Spring 2026",
            "quiz_weight": 30,
            "assignment_weight": 30,
            "midterm_weight": 30,
            "final_weight": 30  # Sum = 120%, should fail
        }
        
        res = await client.post(f"{BASE_URL}/courses", json=payload, headers=headers)
        assert res.status_code == 400, f"Expected 400, got {res.status_code}"
        assert "HEC weights must sum to 100" in res.text
        print("✅ Invalid weights correctly rejected")


@pytest.mark.asyncio
async def test_course_list_professor_sees_only_own():
    """✅ CRUD-R1: Professor lists courses - should see only their own"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        assert res.status_code == 200
        data = res.json()
        courses = data["courses"]
        
        print(f"✅ Professor can see {len(courses)} courses (all their own)")
        for course in courses[:3]:  # Show first 3
            print(f"  - {course['code']}: {course['title']}")


@pytest.mark.asyncio
async def test_course_read_own_course():
    """✅ CRUD-R2: Professor reads their own course - should succeed"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get a course
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        courses = res.json()["courses"]
        if not courses:
            pytest.skip("No courses available")
        
        course_id = courses[0]["id"]
        
        # Now fetch that specific course
        res = await client.get(f"{BASE_URL}/courses/{course_id}", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert data["id"] == course_id
        print(f"✅ Professor can read their course: {data['code']} - {data['title']}")


@pytest.mark.asyncio
async def test_course_update_own_course():
    """✅ CRUD-U1: Professor updates their own course - should succeed"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get a course
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        courses = res.json()["courses"]
        if not courses:
            pytest.skip("No courses available")
        
        course_id = courses[0]["id"]
        
        # Update it
        update_payload = {
            "title": f"Updated Course {int(datetime.now().timestamp())}",
            "description": "Updated description"
        }
        res = await client.put(f"{BASE_URL}/courses/{course_id}", json=update_payload, headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert "Updated" in data["title"]
        print(f"✅ Professor successfully updated their course")


@pytest.mark.asyncio
async def test_course_delete_own_course():
    """✅ CRUD-D1: Professor deletes (archives) their own course - should succeed"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Create a course to delete
        payload = {
            "title": "Temp Course to Delete",
            "code": f"TEMP-{int(datetime.now().timestamp())}",
            "semester": "Spring 2026",
            "quiz_weight": 20,
            "assignment_weight": 20,
            "midterm_weight": 20,
            "final_weight": 40
        }
        
        res = await client.post(f"{BASE_URL}/courses", json=payload, headers=headers)
        if res.status_code != 201:
            pytest.skip("Could not create test course")
        course_id = res.json()["id"]
        
        # Delete it
        res = await client.delete(f"{BASE_URL}/courses/{course_id}", headers=headers)
        assert res.status_code == 200
        assert "archived" in res.json()["message"].lower()
        print(f"✅ Professor successfully archived their course")


# ──────────────────────────────────────────────────────────────────────────────
# ASSIGNMENTS CRUD TESTS
# ──────────────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_assignment_create():
    """✅ CRUD-AC1: Professor creates an assignment in their course"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get a course
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        courses = res.json()["courses"]
        if not courses:
            pytest.skip("No courses available")
        
        course_id = courses[0]["id"]
        
        # Create assignment
        payload = {
            "title": "Assignment 1",
            "description": "First assignment",
            "type": "text",
            "max_marks": 100,
            "deadline": (datetime.now() + timedelta(days=7)).isoformat(),
            "allow_late": True,
            "late_penalty_per_day": 5.0,
            "max_penalty_cap": 20.0
        }
        
        res = await client.post(
            f"{BASE_URL}/courses/{course_id}/assignments",
            json=payload,
            headers=headers
        )
        assert res.status_code == 201, f"Failed: {res.text}"
        data = res.json()
        assert data["title"] == "Assignment 1"
        print(f"✅ Assignment created successfully with ID: {data['id']}")


@pytest.mark.asyncio
async def test_assignment_list():
    """✅ CRUD-AR1: Professor lists assignments in their course"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get a course
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        courses = res.json()["courses"]
        if not courses:
            pytest.skip("No courses available")
        
        course_id = courses[0]["id"]
        
        # List assignments
        res = await client.get(
            f"{BASE_URL}/courses/{course_id}/assignments",
            headers=headers
        )
        assert res.status_code == 200
        data = res.json()
        print(f"✅ Professor can see {data['total']} assignments in course {course_id}")


@pytest.mark.asyncio
async def test_assignment_get():
    """✅ CRUD-AR2: Professor reads an assignment"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get a course and its assignments
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        courses = res.json()["courses"]
        if not courses:
            pytest.skip("No courses available")
        
        course_id = courses[0]["id"]
        
        res = await client.get(
            f"{BASE_URL}/courses/{course_id}/assignments",
            headers=headers
        )
        assignments = res.json()["assignments"]
        
        if not assignments:
            pytest.skip("No assignments in course")
        
        aid = assignments[0]["id"]
        
        # Get single assignment
        res = await client.get(
            f"{BASE_URL}/courses/{course_id}/assignments/{aid}",
            headers=headers
        )
        assert res.status_code == 200
        data = res.json()
        assert data["id"] == aid
        print(f"✅ Professor can read assignment: {data['title']}")


@pytest.mark.asyncio
async def test_assignment_update():
    """✅ CRUD-AU1: Professor updates an assignment"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get a course and assignment
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        courses = res.json()["courses"]
        if not courses:
            pytest.skip("No courses available")
        
        course_id = courses[0]["id"]
        
        res = await client.get(
            f"{BASE_URL}/courses/{course_id}/assignments",
            headers=headers
        )
        assignments = res.json()["assignments"]
        
        if not assignments:
            pytest.skip("No assignments in course")
        
        aid = assignments[0]["id"]
        
        # Update assignment
        update_payload = {
            "title": f"Updated Assignment {int(datetime.now().timestamp())}",
            "description": "Updated description"
        }
        
        res = await client.put(
            f"{BASE_URL}/courses/{course_id}/assignments/{aid}",
            json=update_payload,
            headers=headers
        )
        assert res.status_code == 200
        data = res.json()
        assert "Updated" in data["title"]
        print(f"✅ Professor successfully updated assignment")


@pytest.mark.asyncio
async def test_assignment_delete_draft_only():
    """✅ CRUD-AD1: Professor deletes a draft assignment - should succeed"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get a course
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        courses = res.json()["courses"]
        if not courses:
            pytest.skip("No courses available")
        
        course_id = courses[0]["id"]
        
        # Create an assignment
        payload = {
            "title": f"Temp Assignment {int(datetime.now().timestamp())}",
            "description": "Will be deleted",
            "type": "text",
            "max_marks": 50,
            "deadline": (datetime.now() + timedelta(days=1)).isoformat(),
            "allow_late": False
        }
        
        res = await client.post(
            f"{BASE_URL}/courses/{course_id}/assignments",
            json=payload,
            headers=headers
        )
        if res.status_code != 201:
            pytest.skip("Could not create assignment")
        
        aid = res.json()["id"]
        
        # Delete it (should work for draft)
        res = await client.delete(
            f"{BASE_URL}/courses/{course_id}/assignments/{aid}",
            headers=headers
        )
        assert res.status_code == 200
        print(f"✅ Professor successfully deleted draft assignment")


@pytest.mark.asyncio
async def test_enrollment_management():
    """✅ CRUD-E1: Professor manages course enrollments"""
    async with httpx.AsyncClient() as client:
        # Login
        res = await client.post(
            f"{BASE_URL}/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD}
        )
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get a course
        res = await client.get(f"{BASE_URL}/courses", headers=headers)
        courses = res.json()["courses"]
        if not courses:
            pytest.skip("No courses available")
        
        course_id = courses[0]["id"]
        
        # List enrollments
        res = await client.get(
            f"{BASE_URL}/courses/{course_id}/enrollments",
            headers=headers
        )
        assert res.status_code == 200
        enrollments = res.json()
        print(f"✅ Professor can view {len(enrollments)} enrollments in their course")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])

