# Findings: Scenario AI Failures

Found by: scenario-ai-failures

```
ID: AI-001
Title: Live AI API outage / rate-limit fallback
Severity: P1 (demo-visible)
Found by: scenario-ai-failures
Where: backend/app/services/grading_pipeline.py: _fallback_rubric_evaluation
Steps to reproduce:
  1. Trigger AI evaluation when GROQ_API_KEY is expired, rate-limited (HTTP 429), or venue Wi-Fi drops.
Expected: Fallback mechanism generates grounded rubric score and feedback without 500 error or infinite hang.
Actual: _grade_submission_core catches LLM exceptions and engages _fallback_rubric_evaluation, calculating semantic keyword overlap and criteria scoring deterministically.
Evidence: Line 454-464 in grading_pipeline.py.
Status: fixed
Verified how: Verified in test_grading_pipeline_fix.py (4 passed).
```

```
ID: AI-002
Title: Malformed LLM JSON formatting recovery
Severity: P1 (demo-visible)
Found by: scenario-ai-failures
Where: backend/app/services/grading_pipeline.py: extract_json_payload
Steps to reproduce:
  1. LLM returns JSON wrapped in markdown code blocks or with conversational preamble.
Expected: Parser strips code fences and extracts raw JSON object.
Actual: Regex-based extract_json_payload locates matching outermost braces and parses payload cleanly.
Evidence: Line 240-254 in grading_pipeline.py.
Status: fixed
Verified how: Tested in test_grading_pipeline_fix.py.
```
