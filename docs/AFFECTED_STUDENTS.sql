-- Query to find all students whose MCQ submissions were saved as "[No answers selected]"
-- due to unparsed options fallback in previous versions.
-- Read-only query for auditing and grade adjustment.

SELECT 
    s.id AS submission_id,
    s.assignment_id,
    a.title AS assignment_title,
    a.course_id,
    c.code AS course_code,
    c.title AS course_title,
    s.student_id,
    u.full_name AS student_name,
    u.email AS student_email,
    s.submission_type,
    s.content,
    s.score,
    s.status,
    s.submitted_at,
    s.auto_submitted,
    s.attempt_id
FROM submissions s
JOIN assignments a ON a.id = s.assignment_id
JOIN courses c ON c.id = a.course_id
JOIN users u ON u.id = s.student_id
WHERE a.type = 'mcq'
  AND (
      s.content LIKE '%[No answers selected]%'
      OR s.content LIKE '%[Time Expired - No answers selected]%'
  )
ORDER BY s.submitted_at DESC;
