"""Build the live student dashboard payload from enrolled course data."""

from datetime import datetime, timezone


def _value(value):
    return getattr(value, "value", value)


def build_student_dashboard(courses, assignments, submissions, *, now=None) -> dict:
    now = now or datetime.now(timezone.utc)
    course_map = {course.id: course for course in courses}
    upcoming = []
    feedback = []
    published = 0
    pending = 0
    graded = 0

    for assignment in assignments:
        if _value(assignment.status) != "published" or assignment.course_id not in course_map:
            continue
        published += 1
        submission = submissions.get(assignment.id)
        submission_status = _value(submission.status) if submission else "not_submitted"
        if submission_status == "pending":
            pending += 1
        elif submission_status == "graded":
            graded += 1
            if submission.feedback or submission.score is not None:
                feedback.append({
                    "course_id": assignment.course_id,
                    "assignment_id": assignment.id,
                    "assignment_title": assignment.title,
                    "course_code": course_map[assignment.course_id].code,
                    "score": submission.score,
                    "feedback": submission.feedback or "",
                    "graded_at": submission.graded_at.isoformat() if submission.graded_at else None,
                })
        if assignment.deadline and assignment.deadline >= now:
            upcoming.append({
                "course_id": assignment.course_id,
                "assignment_id": assignment.id,
                "title": assignment.title,
                "course_code": course_map[assignment.course_id].code,
                "deadline": assignment.deadline.isoformat(),
                "submitted": submission is not None,
                "submission_status": submission_status,
            })

    upcoming.sort(key=lambda item: item["deadline"])
    feedback.sort(key=lambda item: item["graded_at"] or "", reverse=True)
    return {
        "courses": [
            {
                "id": course.id,
                "title": course.title,
                "code": course.code,
                "semester": course.semester,
                "assignment_count": sum(
                    1 for assignment in assignments
                    if assignment.course_id == course.id and _value(assignment.status) == "published"
                ),
            }
            for course in courses
        ],
        "upcoming": upcoming[:10],
        "feedback": feedback[:10],
        "stats": {
            "enrolled_courses": len(courses),
            "published_assignments": published,
            "pending": pending,
            "graded": graded,
        },
    }
