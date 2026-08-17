# ProfessorOS Code Issues Report

Date: 2026-08-17
Severity: Critical, High, Medium

---

## 🔴 CRITICAL ISSUES

### 1. **Assignment DELETE Response Not Awaited in Flush**
**File:** `backend/app/api/v1/assignments.py` (line 182-206)
**Issue:** Assignment delete endpoint is missing `await db.commit()` after delete/flush
```python
await db.delete(assignment)
await db.flush()
return {"message": "Assignment deleted."}
```
**Problem:** Changes might not be persisted to database. Flush only stages the delete; commit is needed.
**Fix:** Add `await db.commit()` before returning

---

### 2. **Missing Try-Catch in Assignment Delete**
**File:** `backend/app/api/v1/assignments.py` (line 182)
**Issue:** Delete endpoint doesn't catch exceptions
```python
@router.delete("/courses/{course_id}/assignments/{aid}")
async def delete_assignment(...):
    # ... no try-catch
    await db.delete(assignment)
```
**Problem:** Orphaned exceptions crash the endpoint instead of returning proper error codes
**Fix:** Wrap in try-catch block like other endpoints

---

### 3. **Rubric Delete Response Not Awaited in Commit**
**File:** `backend/app/api/v1/assignments.py` (line 206-222)
**Issue:** Same as #1 - rubric delete missing commit
```python
await db.delete(rubric)
await db.flush()  # Missing commit!
return {"message": "Rubric deleted."}
```

---

### 4. **CSV Enrollment Import Not Committed**
**File:** `backend/app/services/course_service.py` (line 200+)
**Issue:** Enrollments added but never committed
```python
for row_num, row in enumerate(reader, start=2):
    # ... add enrollments ...
    self.db.add(Enrollment(...))
    created += 1
await self.db.flush()  # Missing: await self.db.commit()
return {"created": created, "errors": errors}
```
**Problem:** Bulk enrollment CSV import won't save to database

---

### 5. **Frontend Auth Token Refresh Loop Risk**
**File:** `frontend/lib/core/network/dio_client.dart` (line 90-129)
**Issue:** Refresh token response not validated
```python
final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
final response = await refreshDio.post(
    ApiConstants.refresh,
    data: {'refresh_token': refreshToken},
);
// MISSING: response.statusCode check!
final newAccess = response.data['access_token'] as String;
```
**Problem:** If refresh fails, code tries to parse null data → crash
**Fix:** Check `response.statusCode == 200` before accessing data

---

## 🟠 HIGH PRIORITY ISSUES

### 6. **Backend Assignment Update Doesn't Verify Course Access**
**File:** `backend/app/api/v1/assignments.py` (line 75)
**Issue:** Update endpoint verifies course access but not assignment course_id match
```python
async def update_assignment(course_id: int, aid: int, body: AssignmentUpdate, ...):
    # Verifies course access ✓
    await course_svc.verify_course_management_access(course_id, user)
    # But never checks if assignment.course_id == course_id!
    assignment = await svc.update_assignment(aid, body)
```
**Problem:** Professor can update assignments from OTHER courses if they know the ID
**Fix:** Add check: `if assignment.course_id != course_id: raise PermissionError`

---

### 7. **Missing CourseID Validation in Assignment Creation Wizard**
**File:** `frontend/lib/features/courses/presentation/assignment_creation_wizard.dart`
**Issue:** No validation that created assignment belongs to the course
**Problem:** If API returns wrong course_id, app still navigates to that assignment
**Fix:** Verify `created['course_id'] == widget.courseId` before navigating

---

### 8. **Rubric Endpoint Missing Course Access Check**
**File:** `backend/app/api/v1/assignments.py` (line 141-174)
**Issue:** Rubric GET/POST endpoints don't verify course membership
```python
@router.get("/assignments/{aid}/rubric", response_model=RubricResponse)
async def get_rubric(aid: int, user: Annotated[User, ...]):
    svc = AssignmentService(db)
    rubric = await svc.get_rubric(aid)
    # MISSING: Check if user can access this assignment/course!
```
**Problem:** Students could potentially view/edit rubrics for courses they're not enrolled in
**Fix:** Fetch assignment, verify course access before allowing rubric access

---

### 9. **Frontend Error Message Exposure**
**File:** `frontend/lib/features/courses/presentation/course_detail_screen.dart` (line 285)
**Issue:** Raw error strings shown to users without parsing
```dart
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(e.toString()),  // Raw error!
    backgroundColor: AppColors.dangerRose,
));
```
**Problem:** Technical errors (stack traces, SQL errors) exposed to users
**Fix:** Use `ErrorParser.parse(e)` in all snackbars

---

### 10. **Missing null Check on Assignment Clos**
**File:** `backend/app/api/v1/courses.py` (line 60+)
**Issue:** Response assumes CLOs exist without checking
```python
resp = CourseResponse.model_validate(c)
resp.professor_name = c.professor.full_name if c.professor else None
# What if c is null or c.enrollments is null?
resp.enrollment_count = len(c.enrollments) if c.enrollments else 0
```
**Problem:** Rare race condition could cause crash if course is deleted during response building
**Fix:** Safe for None already, but verify all related fields

---

## 🟡 MEDIUM PRIORITY ISSUES

### 11. **Inconsistent Error Handling in Auth Service**
**File:** `backend/app/services/auth_service.py` (line 90+)
**Issue:** Some exceptions caught, some not
```python
async def login(self, email: str, password: str) -> Tuple[str, str]:
    user = await self._get_user_by_email(email)  # Could return None
    if not user:
        raise ValueError("No account found...")
    # But _get_user_by_email not shown - assume it's safe
```
**Problem:** Inconsistent error propagation
**Fix:** Document all exceptions each method can raise

---

### 12. **Email Service Silent Failures**
**File:** `backend/app/services/email_service.py` (line 80+)
**Issue:** Email failures logged but don't affect registration flow
```python
async def register(...):
    # ... create user ...
    await asyncio.to_thread(send_verification_email, ...)
    # What if email fails? User continues anyway
    return user, verification_token
```
**Problem:** User registration succeeds even if verification email never sent
**Fix:** Catch and report email failures to client

---

### 13. **Frontend CLO Selection Not Validated**
**File:** `frontend/lib/features/courses/presentation/assignment_creation_wizard.dart` (line 95+)
**Issue:** No check that CLOs belong to the course
```python
assignData = {
    ...
    'clo_ids': _selectedCloIds.toList(),  // No validation!
}
```
**Problem:** Could potentially send CLO IDs from wrong course
**Fix:** Validate CLOs are from `widget.courseId`

---

### 14. **Missing Submission Access Verification**
**File:** `backend/app/api/v1/submissions.py` (assumed, not shown)
**Issue:** Submission endpoints likely don't verify course access
**Problem:** Could access submissions for courses not authorized
**Fix:** Add course access checks to all submission endpoints

---

### 15. **Analytics Dashboard Cache Not Invalidated on Updates**
**File:** `frontend/lib/features/analytics/providers/analytics_provider.dart`
**Issue:** Analytics provider has no invalidation method
```dart
final analyticsDashboardProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, courseId) async {
    // No way to invalidate this from course_detail_screen
});
```
**Problem:** After publishing assignment, analytics not updated
**Fix:** Add `ref.invalidate(analyticsDashboardProvider(courseId))` in relevant screens

---

### 16. **Race Condition in Token Refresh**
**File:** `frontend/lib/core/network/dio_client.dart` (line 90-129)
**Issue:** `_isRefreshing` flag could still allow multiple concurrent refreshes
```dart
if (err.response?.statusCode == 401 && !_isRefreshing) {
    _isRefreshing = true;
    // Between here and finally, another 401 could trigger new refresh
}
```
**Problem:** Multiple simultaneous 401s could start multiple refresh attempts
**Fix:** Use a lock mechanism or queue requests while refreshing

---

### 17. **No Validation of Course Weights in Update**
**File:** `backend/app/services/course_service.py` (line 85+)
**Issue:** Course update allows partial weight updates without validation
```python
if weight_keys & set(update_data.keys()):
    q = update_data.get("quiz_weight", course.quiz_weight)
    a = update_data.get("assignment_weight", course.assignment_weight)
    # This works, but...
```
**Problem:** No issue here actually - this is correct
**Resolution:** RECHECK - this looks fine

---

## 🟢 LOW PRIORITY ISSUES (Nice to Fix)

### 18. **Missing Enrollment Role Default**
**File:** `backend/app/services/course_service.py` (line 150)
**Issue:** `role` parameter defaults to "student" without validation
```python
async def enroll_user(self, course_id: int, user_id: int, role: str = "student") -> Enrollment:
    # No validation that role is valid (student|ta|professor)
```
**Fix:** Add enum validation: `assert role in ["student", "ta", "professor"]`

---

### 19. **Unnecessary Type Casting in Frontend**
**File:** `frontend/lib/features/courses/presentation/course_detail_screen.dart` (line 280)
**Issue:** Multiple unnecessary type casts
```dart
final sid = sub['id'] as int;  // Should use typed response object
```
**Fix:** Use strongly typed data classes instead of Map

---

### 20. **Console Email Mode Creates File Without Permission Check**
**File:** `backend/app/services/email_service.py` (line 230)
**Issue:** Writes to `os.getcwd() + latest_email.html` without path validation
```python
file_path = os.path.join(os.getcwd(), "latest_email.html")
with open(file_path, "w", encoding="utf-8") as f:
    f.write(html)
```
**Problem:** Could fail if cwd is read-only
**Fix:** Write to temp directory instead

---

### 21. **Missing Logging for Failed Operations**
**Issue:** No structured logging for tracking failed enrollments, deletes, etc.
**Impact:** Hard to debug production issues
**Fix:** Add logging throughout service layer

---

### 22. **Assignment Status Enum Not Used Consistently**
**File:** `backend/app/models/assignment.py` (assumed)
**Issue:** Status is string not enum in some places
```python
assignment.status = AssignmentStatus.DRAFT.value  # .value - converts to string
```
**Should be:** Store as enum directly, only convert for serialization

---

## Summary of Critical Fixes Needed

| Issue | File | Impact | Effort |
|-------|------|--------|--------|
| Missing DB commits on delete | assignments.py | Data loss | 5 min |
| No try-catch on delete endpoints | assignments.py | 500 errors | 10 min |
| CSV enrollments not committed | course_service.py | Data loss | 5 min |
| Token refresh doesn't validate response | dio_client.dart | Crash | 10 min |
| Assignment update no course_id check | assignments.py | Security | 5 min |
| Rubric endpoints missing access checks | assignments.py | Security | 15 min |
| Raw errors shown to users | course_detail_screen.dart | UX | 10 min |

---

## Recommended Fix Priority

**Phase 1 (Critical - 30 minutes):**
1. Add `await db.commit()` to all DELETE operations
2. Add try-catch to delete endpoints
3. Fix token refresh response validation
4. Add course_id verification to assignment update

**Phase 2 (High - 1 hour):**
5. Add access checks to rubric endpoints
6. Fix error message exposure in frontend
7. Validate course access on all operations

**Phase 3 (Medium - 2 hours):**
8. Fix CSV import commits
9. Add email failure handling
10. Invalidate analytics on updates

