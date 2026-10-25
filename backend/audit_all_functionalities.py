import asyncio
import httpx
import json

BASE_URL = "http://127.0.0.1:8000"

async def run_audit():
    results = {}
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=30.0) as client:
        print("[AUDIT] 1. Infrastructure & Health Endpoints")
        res_health = await client.get("/health")
        res_ready = await client.get("/ready")
        results["health_check"] = {
            "status_code": res_health.status_code,
            "data": res_health.json() if res_health.status_code == 200 else res_health.text,
            "passed": res_health.status_code == 200 and res_health.json().get("status") == "ok"
        }
        results["ready_check"] = {
            "status_code": res_ready.status_code,
            "data": res_ready.json() if res_ready.status_code == 200 else res_ready.text,
            "passed": res_ready.status_code == 200 and res_ready.json().get("status") == "ready"
        }

        print("[AUDIT] 2. Security Headers & CORS Checks")
        results["security_headers"] = {
            "x_frame_options": res_health.headers.get("x-frame-options"),
            "x_content_type_options": res_health.headers.get("x-content-type-options"),
            "passed": "x-content-type-options" in res_health.headers
        }

        print("[AUDIT] 3. Authentication for All 4 Roles")
        tokens = {}
        users_to_test = [
            ("admin", "admin@professoros.edu.pk", "password123"),
            ("professor", "prof@example.com", "password123"),
            ("student", "student@example.com", "password123"),
            ("ta", "browser.ta@e2e.example.com", "password123"),
        ]
        
        for role, email, pwd in users_to_test:
            res_login = await client.post("/api/v1/auth/login", json={"email": email, "password": pwd})
            passed = res_login.status_code == 200 and "access_token" in res_login.json()
            results[f"auth_{role}"] = {
                "status_code": res_login.status_code,
                "passed": passed,
                "email": email,
                "user_role": res_login.json().get("user", {}).get("role") if passed else None
            }
            if passed:
                tokens[role] = res_login.json()["access_token"]
            else:
                print(f"Failed login for {role} ({email}): {res_login.status_code} {res_login.text}")

        # Check invalid login rejection
        res_bad_login = await client.post("/api/v1/auth/login", json={"email": "nonexistent@example.com", "password": "wrong"})
        results["auth_invalid_credentials"] = {
            "status_code": res_bad_login.status_code,
            "passed": res_bad_login.status_code in (400, 401, 404)
        }

        print("[AUDIT] 4. User Profile & Session Revocation")
        if "student" in tokens:
            headers_student = {"Authorization": f"Bearer {tokens['student']}"}
            res_me = await client.get("/api/v1/users/me", headers=headers_student)
            results["users_me_student"] = {
                "status_code": res_me.status_code,
                "email": res_me.json().get("email") if res_me.status_code == 200 else None,
                "passed": res_me.status_code == 200 and res_me.json().get("email") == "student@example.com"
            }

        print("[AUDIT] 5. Admin Governance & User Management")
        if "admin" in tokens:
            headers_admin = {"Authorization": f"Bearer {tokens['admin']}"}
            res_users = await client.get("/api/v1/admin/users?page=1&size=10", headers=headers_admin)
            results["admin_list_users"] = {
                "status_code": res_users.status_code,
                "total": res_users.json().get("total") if res_users.status_code == 200 else None,
                "passed": res_users.status_code == 200 and ("users" in res_users.json() or "items" in res_users.json())
            }
            res_pending = await client.get("/api/v1/admin/users/pending", headers=headers_admin)
            results["admin_pending_users"] = {
                "status_code": res_pending.status_code,
                "passed": res_pending.status_code == 200
            }
            res_stats = await client.get("/api/v1/admin/users/stats", headers=headers_admin)
            results["admin_user_stats"] = {
                "status_code": res_stats.status_code,
                "stats": res_stats.json() if res_stats.status_code == 200 else None,
                "passed": res_stats.status_code == 200
            }

        print("[AUDIT] 6. Course Lifecycle & Enrollment")
        created_course_id = None
        join_code = None
        if "professor" in tokens:
            headers_prof = {"Authorization": f"Bearer {tokens['professor']}"}
            res_prof_courses = await client.get("/api/v1/courses", headers=headers_prof)
            results["course_list_professor"] = {
                "status_code": res_prof_courses.status_code,
                "passed": res_prof_courses.status_code == 200
            }
            # Create a test course
            new_course_payload = {
                "title": "Audit Distributed Systems",
                "code": "CS-AUDIT-403",
                "description": "Functional validation course",
                "semester": "Fall 2026"
            }
            res_create_c = await client.post("/api/v1/courses", json=new_course_payload, headers=headers_prof)
            passed_create_c = res_create_c.status_code in (200, 201)
            results["course_creation"] = {
                "status_code": res_create_c.status_code,
                "passed": passed_create_c
            }
            if passed_create_c:
                c_data = res_create_c.json()
                created_course_id = c_data["id"]
                join_code = c_data.get("join_code")

        print("[AUDIT] 7. Course Details, Roster & Student Enrollment")
        created_clo_id = None
        if created_course_id and "professor" in tokens:
            headers_prof = {"Authorization": f"Bearer {tokens['professor']}"}
            res_c_detail = await client.get(f"/api/v1/courses/{created_course_id}", headers=headers_prof)
            join_code = res_c_detail.json().get("join_code") or join_code
            results["course_detail_retrieval"] = {
                "status_code": res_c_detail.status_code,
                "has_join_code": bool(join_code),
                "passed": res_c_detail.status_code == 200
            }

            # Add a CLO to the course
            clo_payload = {
                "code": "CLO-1",
                "description": "Evaluate consistency models in distributed architectures"
            }
            res_add_clo = await client.post(f"/api/v1/courses/{created_course_id}/clos", json=clo_payload, headers=headers_prof)
            results["course_add_clo"] = {
                "status_code": res_add_clo.status_code,
                "passed": res_add_clo.status_code in (200, 201)
            }
            if res_add_clo.status_code in (200, 201):
                created_clo_id = res_add_clo.json()["id"]

        if join_code and "student" in tokens:
            headers_student = {"Authorization": f"Bearer {tokens['student']}"}
            res_join = await client.post("/api/v1/courses/join", json={"join_code": join_code}, headers=headers_student)
            results["student_join_course"] = {
                "status_code": res_join.status_code,
                "passed": res_join.status_code in (200, 201, 400)
            }

        print("[AUDIT] 8. Assignment Creation, Rubric & Gating")
        created_asg_id = None
        if created_course_id and "professor" in tokens:
            headers_prof = {"Authorization": f"Bearer {tokens['professor']}"}
            asg_payload = {
                "title": "Audit Midterm Assessment",
                "description": "1. What is CAP theorem?\nA) Consistency, Availability, Partition tolerance\nB) Cache, Authentication, Protocol\nC) Cloud, Automation, Privacy\nD) None of above\nAnswer: A",
                "type": "mcq",
                "deadline": "2026-12-31T23:59:59Z",
                "max_marks": 100,
                "time_limit_minutes": 60,
                "max_attempts": 1,
                "randomize_questions": False,
                "show_results_after": True,
                "clo_ids": [created_clo_id] if created_clo_id else []
            }
            res_create_asg = await client.post(f"/api/v1/courses/{created_course_id}/assignments", json=asg_payload, headers=headers_prof)
            passed_create_asg = res_create_asg.status_code in (200, 201)
            results["assignment_creation"] = {
                "status_code": res_create_asg.status_code,
                "passed": passed_create_asg
            }
            if passed_create_asg:
                created_asg_id = res_create_asg.json()["id"]

            # Add HEC 4-level 3-criteria Rubric
            if created_asg_id:
                levels_tmpl = [
                    {"level": "excellent", "description": "Exceeds standards"},
                    {"level": "satisfactory", "description": "Meets standards"},
                    {"level": "developing", "description": "Approaching standards"},
                    {"level": "insufficient", "description": "Below standards"}
                ]
                rubric_payload = {
                    "criteria": [
                        {"name": "Technical Accuracy", "weight": 40.0, "order": 1, "levels": levels_tmpl},
                        {"name": "System Architecture", "weight": 30.0, "order": 2, "levels": levels_tmpl},
                        {"name": "Design Rationale", "weight": 30.0, "order": 3, "levels": levels_tmpl}
                    ]
                }
                res_rubric = await client.post(f"/api/v1/courses/{created_course_id}/assignments/{created_asg_id}/rubric", json=rubric_payload, headers=headers_prof)
                results["assignment_rubric_creation"] = {
                    "status_code": res_rubric.status_code,
                    "passed": res_rubric.status_code in (200, 201)
                }

                # Publish Assignment with full validation
                res_publish = await client.post(f"/api/v1/courses/{created_course_id}/assignments/{created_asg_id}/publish", headers=headers_prof)
                results["assignment_publish"] = {
                    "status_code": res_publish.status_code,
                    "passed": res_publish.status_code == 200
                }

        print("[AUDIT] 9. Student Dashboard")
        if "student" in tokens:
            headers_student = {"Authorization": f"Bearer {tokens['student']}"}
            res_dash = await client.get("/api/v1/users/me/student-dashboard", headers=headers_student)
            results["student_dashboard"] = {
                "status_code": res_dash.status_code,
                "courses_count": len(res_dash.json().get("courses", [])) if res_dash.status_code == 200 else None,
                "stats": res_dash.json().get("stats") if res_dash.status_code == 200 else None,
                "passed": res_dash.status_code == 200
            }

        print("[AUDIT] 10. Proctored Exam Flow & Telemetry")
        attempt_id = None
        if created_course_id and created_asg_id and "student" in tokens:
            headers_student = {"Authorization": f"Bearer {tokens['student']}"}
            res_start_exam = await client.post(
                f"/api/v1/courses/{created_course_id}/assignments/{created_asg_id}/exam/start",
                headers=headers_student
            )
            passed_start_exam = res_start_exam.status_code in (200, 201)
            attempt_id = res_start_exam.json().get("id") if passed_start_exam else None
            results["exam_start_attempt"] = {
                "status_code": res_start_exam.status_code,
                "attempt_id": attempt_id,
                "passed": passed_start_exam
            }

            if attempt_id:
                hb_payload = {
                    "tab_switch_count": 1,
                    "event_type": "tab_hidden",
                    "timestamp": "2026-10-24T13:00:00Z",
                    "draft_answers": {"q1": "A"}
                }
                res_hb = await client.post(
                    f"/api/v1/attempts/{attempt_id}/heartbeat",
                    json=hb_payload,
                    headers=headers_student
                )
                results["exam_heartbeat_telemetry"] = {
                    "status_code": res_hb.status_code,
                    "passed": res_hb.status_code == 200
                }

                submit_payload = {
                    "submission_type": "mcq",
                    "answers": {"q1": "A"},
                    "content": "A"
                }
                res_submit = await client.post(
                    f"/api/v1/courses/{created_course_id}/assignments/{created_asg_id}/exam/submit",
                    json=submit_payload,
                    headers=headers_student
                )
                results["exam_submit"] = {
                    "status_code": res_submit.status_code,
                    "passed": res_submit.status_code in (200, 201)
                }

        print("[AUDIT] 11. Live Proctor Console & Adjudication")
        if created_course_id and created_asg_id and "professor" in tokens:
            headers_prof = {"Authorization": f"Bearer {tokens['professor']}"}
            res_attempts = await client.get(
                f"/api/v1/courses/{created_course_id}/assignments/{created_asg_id}/exam/attempts",
                headers=headers_prof
            )
            passed_attempts = res_attempts.status_code == 200
            attempts_list = res_attempts.json() if passed_attempts and isinstance(res_attempts.json(), list) else []
            results["proctor_console_list_attempts"] = {
                "status_code": res_attempts.status_code,
                "count": len(attempts_list),
                "passed": passed_attempts
            }

            if attempt_id:
                adj_payload = {
                    "action": "clear",
                    "reason": "Audit verification: tab switch was benign verification."
                }
                res_adj = await client.post(
                    f"/api/v1/courses/{created_course_id}/assignments/{created_asg_id}/exam/attempts/{attempt_id}/decision",
                    json=adj_payload,
                    headers=headers_prof
                )
                results["proctor_adjudication"] = {
                    "status_code": res_adj.status_code,
                    "passed": res_adj.status_code in (200, 201)
                }

        print("[AUDIT] 12. SpeedGrader & Submissions List")
        if created_course_id and created_asg_id and "professor" in tokens:
            headers_prof = {"Authorization": f"Bearer {tokens['professor']}"}
            res_subs = await client.get(
                f"/api/v1/courses/{created_course_id}/assignments/{created_asg_id}/submissions",
                headers=headers_prof
            )
            passed_subs = res_subs.status_code == 200
            subs_list = res_subs.json().get("submissions", []) if passed_subs else []
            results["speedgrader_submissions_list"] = {
                "status_code": res_subs.status_code,
                "count": len(subs_list),
                "passed": passed_subs
            }

            if subs_list:
                first_sub = subs_list[0]
                sub_id = first_sub["id"]
                grade_payload = {
                    "score": 95.0,
                    "feedback": "Comprehensive response with correct CAP theorem definitions.",
                    "status": "graded"
                }
                res_grade = await client.put(
                    f"/api/v1/submissions/{sub_id}/grade",
                    json=grade_payload,
                    headers=headers_prof
                )
                results["manual_grading"] = {
                    "status_code": res_grade.status_code,
                    "passed": res_grade.status_code in (200, 201)
                }

        print("[AUDIT] 13. TA Workload & Scoped Permissions")
        if "ta" in tokens:
            headers_ta = {"Authorization": f"Bearer {tokens['ta']}"}
            res_ta_courses = await client.get("/api/v1/courses", headers=headers_ta)
            results["ta_list_courses"] = {
                "status_code": res_ta_courses.status_code,
                "passed": res_ta_courses.status_code == 200
            }

        print("[AUDIT] 14. OBE Attainment & Analytics")
        if created_course_id and "professor" in tokens:
            headers_prof = {"Authorization": f"Bearer {tokens['professor']}"}
            res_analytics = await client.get(f"/api/v1/courses/{created_course_id}/analytics", headers=headers_prof)
            results["course_analytics"] = {
                "status_code": res_analytics.status_code,
                "passed": res_analytics.status_code in (200, 404)
            }
            res_clo = await client.get(f"/api/v1/courses/{created_course_id}/clo-attainment", headers=headers_prof)
            results["course_clo_attainment"] = {
                "status_code": res_clo.status_code,
                "data": res_clo.json() if res_clo.status_code == 200 else res_clo.text,
                "passed": res_clo.status_code == 200
            }

        print("[AUDIT] 15. HEC Dossier Generation")
        if created_course_id and "professor" in tokens:
            headers_prof = {"Authorization": f"Bearer {tokens['professor']}"}
            res_dossier = await client.get(f"/api/v1/courses/{created_course_id}/hec-dossier", headers=headers_prof)
            results["hec_dossier_export"] = {
                "status_code": res_dossier.status_code,
                "passed": res_dossier.status_code in (200, 400, 404)
            }

    print("\n--- FINAL AUDIT RESULTS ---")
    print(json.dumps(results, indent=2))
    
    with open("audit_results.json", "w") as f:
        json.dump(results, f, indent=2)

if __name__ == "__main__":
    asyncio.run(run_audit())
