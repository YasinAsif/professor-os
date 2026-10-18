# OBE & CLO Attainment Operational Specification

> **Accreditation Standard:** HEC / Washington Accord Outcome-Based Education (OBE) cohort attainment metrics.

---

## 1. Missing Attempts Decision & Attainment Policy
- **Question:** Do missing attempts count as zero or get excluded in cohort attainment?
- **Decision:**
  - **Cohort Participation Cohort:** Enrolled students who never submit or never start an attempt are recorded as **missing attempts**.
  - For formal cohort attainment calculations, unsubmitted assignments receive **0.0 earned score** against the assessment max marks if the student was enrolled at the assessment deadline.
  - For formative assessment analysis, the professor console displays the participating cohort percentage alongside the overall enrolled cohort attainment.
  - Submissions with `status == "invalidated"` (due to confirmed proctoring violations or disciplinary decisions) are **strictly excluded** from CLO attainment so that fraudulent submissions do not distort academic achievement metrics.

---

## 2. Canonical CLO Data Source
- The platform uses **ONE canonical CLO source**: the `clos` database table (`app.models.course.CLO`), mapped to courses via `course_id`.
- Assessment linkage is established via the `assignment_clos` association table (`assignment_id`, `clo_id`).
- **No Synthetic Bloom's Guess:** Legacy fallbacks that assumed `'C3'` for unclassified CLOs have been completely removed. If a CLO's cognitive Bloom's level is not specified, it is displayed as `'Unspecified'` or empty rather than fabricating a C3 level.
- When an assessment has no student submissions, the system reports **"No assessment data available"** rather than generating fake 0% or 100% attainment figures.

---

## 3. Database Schema Reconciliations
- **At-Risk Table Naming:** The canonical table name is `at_risk_records` (model `AtRiskRecord` in `app.models.analytics`). All documentation references to `at_risks` or `student_at_risk` are legacy errata.
- **Attainment Records:** Historical snapshots are persisted in `attainment_records`.
