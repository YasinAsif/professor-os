# ProfessorOS – Brand & Product Context

> **Note to AI / Branding Assistants:**  
> Use the following context about ProfessorOS to generate branding assets, marketing copy, feature announcements, and brand guidelines. This document serves as the absolute source of truth for the platform's architecture, target audience, UI/UX philosophy, and feature set.

---

## 1. Product Overview

**Name:** ProfessorOS  
**Tagline:** Smart academic platform for Pakistani universities.  
**Core Purpose:** To modernize and streamline university course management, grading, and accreditation tracking. It heavily emphasizes compliance with the Higher Education Commission (HEC) of Pakistan, specifically regarding CLO (Course Learning Outcomes) mapping and standardized rubrics.  
**Platforms:** A unified Flutter application deployed as a **Mobile App (APK/iOS)** and a **Web Application**.  
**Tech Stack:** Flutter (Frontend), FastAPI + PostgreSQL + SQLAlchemy (Backend), deployed on Railway.

**Primary User Personas:**
1. **Professors/Instructors:** Create courses, design HEC-compliant rubrics, oversee TAs, and monitor student analytics.
2. **Teaching Assistants (TAs):** Manage the grading workload across assigned courses using a high-efficiency grading interface.
3. **Students:** View enrolled courses, submit assignments, and track their grades and feedback.
4. **Admins:** Manage user accounts, import student rosters via CSV, and oversee platform health.

---

## 2. Design Philosophy: "Marginalia"

ProfessorOS completely rejects the "generic SaaS dashboard" look (which typically relies on indigo gradients, heavy shadows, and rounded glassmorphism). Instead, we designed **Marginalia**, a bespoke design system inspired by academic papers, ledgers, and classic typography. 

**Core Aesthetic Principles:**
- **Digital Paper:** The app feels like reading a beautifully typeset academic journal or an accountant's ledger. 
- **Flat & Precise:** Absolutely no drop shadows, glows, or gradients. Depth is created through strict, hairline borders and subtle color contrasts.
- **No Dark Mode:** The app is strictly designed for light mode to maintain the "paper and ink" metaphor.

**Color Palette:**
- **Backgrounds:** Warm Canvas (`#F6F5F0`) for the app background, White (`#FFFFFF`) for content cards and inputs.
- **Ink (Text):** Fountain-pen Navy (`#1E2A38`) for primary text/headings, Muted Slate (`#5B6470`) for secondary text.
- **Accents:** 
  - *Signal (Interactive):* Classic Navy (`#2F5D8A`) for primary buttons and active states.
  - *Success / Verified:* Forest Green (`#3F6B4F`).
  - *Pending / Warning:* Academic Amber (`#B5872A`).
  - *Feedback / Error:* Red Ink (`#B4432E`), used strictly for grading deductions or errors.

**Typography:**
- **Headings & Titles:** *Fraunces* (A beautiful, high-contrast serif that feels academic and premium).
- **Body & UI Elements:** *Inter* (A highly legible, neutral sans-serif).
- **Data & Metrics:** *JetBrains Mono* (For tabular data, codes, and numerical metrics).

---

## 3. Screen-by-Screen Breakdown

Both the Web and Mobile versions share the same codebase and adapt responsively to screen sizes. The web version utilizes a left-side "Ledger Rail" navigation menu, while the mobile version uses a sleek bottom navigation bar.

### A. Authentication Flows
- **Login / Register / Forgot Password:** Clean, distraction-free cards centered on the warm canvas. Uses segmented buttons to select roles (Professor, Student, TA) during onboarding. Inputs feature hairline borders that turn navy when focused.

### B. Dashboards (Role-Based)
- **Student Dashboard:** Displays a personalized greeting, quick KPI metrics (Enrolled, Pending, Graded), and a "My Courses" list. Includes a dialogue to join new courses using a 6-character code.
- **TA Dashboard:** Built purely for grading efficiency. Features "Workload KPIs" (Pending, Graded, Turnaround Time), and a prioritized "Needs Grading" queue that pulls ungraded submissions from all assigned courses.
- **Professor Dashboard (Course List):** A high-level view of all active courses being taught, with a prominent action to create new courses.

### C. Course Management
- **Create Course Screen:** A clean form to input course title, code, semester, and description.
- **Course Detail Screen:** The hub for a specific course. Features an overview of the curriculum, a list of created assignments, and options to manage enrolled students or export rosters via CSV.

### D. Assignments & Grading
- **Assignment Creation Wizard:** A multi-step flow allowing professors to define the assignment, attach HEC-aligned CLOs (Course Learning Outcomes), and build custom grading rubrics.
- **Assignment Detail & SpeedGrader:** The crown jewel of the platform. On web, it utilizes a split-screen view: the student's submission is on the left, and an interactive, clickable rubric is on the right. TAs and Professors can click rubric cells to instantly tally grades without manual math.

### E. Analytics & Insights
- **Analytics Dashboard:** A data-rich screen using clean charts to visualize class performance. It highlights "At-Risk Students" and generates graphs showing how well the class is achieving specific HEC Course Learning Outcomes.

### F. Administration
- **User Management:** A robust data table view for Admins to manage all accounts, toggle active status, change roles, and mass-import students via CSV files.

---

## 4. Branding Directives

When generating copy, marketing materials, or further design assets based on this context, ensure the tone reflects the **Marginalia** aesthetic:
- **Tone of Voice:** Academic, precise, premium, and calm. Avoid hyper-energetic startup jargon (e.g., avoid "Supercharge your workflow 🚀"). Prefer confident, elegant phrasing (e.g., "Clarity in every grade. Precision in every outcome.").
- **Visuals:** Emphasize the lack of clutter. Highlight the typography, the paper-like background, and the fact that ProfessorOS respects the user's focus. 
- **Key Selling Points:** The HEC compliance (CLO tracking), the SpeedGrader (saving hours of TA time), and the bespoke, premium UI.
