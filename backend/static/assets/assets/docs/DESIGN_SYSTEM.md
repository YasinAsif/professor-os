# ProfessorOS — Brand & Design Guidelines
### Design System: *Marginalia* · v1.0

> This document is the single source of truth for all design decisions across ProfessorOS. Every new screen, component, marketing asset, and copy block must pass the **Marginalia** test: does it look and feel like a page from a precision-typeset academic journal? If not, revise before shipping.

---

## Table of Contents

1. [Brand Foundation](#1-brand-foundation)
2. [Design Philosophy: Marginalia](#2-design-philosophy-marginalia)
3. [Color System](#3-color-system)
4. [Typography System](#4-typography-system)
5. [Spacing & Layout](#5-spacing--layout)
6. [Component Library](#6-component-library)
7. [Iconography](#7-iconography)
8. [Platform Adaptations](#8-platform-adaptations)
9. [Motion & Interaction](#9-motion--interaction)
10. [Tone of Voice & Copywriting](#10-tone-of-voice--copywriting)
11. [Do's & Don'ts](#11-dos--donts)
12. [Accessibility Standards](#12-accessibility-standards)

---

## 1. Brand Foundation

### 1.1 Identity

| Attribute     | Value                                                             |
|---------------|-------------------------------------------------------------------|
| **Name**      | ProfessorOS                                                       |
| **Tagline**   | Smart academic platform for Pakistani universities.               |
| **Core Role** | Modernize course management, grading, and HEC accreditation tracking |
| **Audience**  | Professors, Teaching Assistants, Students, Admins                 |
| **Platforms** | Web (Flutter Web) · Mobile (Flutter APK / iOS)                   |

### 1.2 Brand Pillars

**Precision.** Every element has a reason to exist. Clutter is an error, not an oversight.

**Authority.** ProfessorOS carries the weight of an academic institution. It is not playful; it is trustworthy.

**Legibility.** The platform serves people who are reading, evaluating, and deciding. Nothing competes with the content.

**Restraint.** Visual flourishes are not rewards. They are costs. Spend them carefully.

---

## 2. Design Philosophy: Marginalia

**Marginalia** is the bespoke design system powering ProfessorOS. The name is a reference to the practice of writing notes in the margins of academic texts — precise, purposeful, and subordinate to the primary content.

### 2.1 Core Metaphor

The interface is a **printed academic document**: a well-typeset journal, a professor's ledger, an examination register. Everything — from the background color to the button radius — should be justifiable by asking: *would you find this in a premium academic publication?*

This means:
- Paper-like warmth, not cold tech blue-grays
- Ink-like text contrast, not anti-aliased gray blobs
- Ledger-line borders, not floating card shadows
- Margin-based hierarchy, not colorful badge clusters

### 2.2 The Three Rejections

Marginalia is defined as much by what it **refuses** as by what it embraces:

| Rejected Pattern         | Why                                              | Marginalia Alternative                    |
|--------------------------|--------------------------------------------------|-------------------------------------------|
| Indigo/purple gradients  | Generic SaaS; signals "made from a template"     | Flat Classic Navy `#2F5D8A`               |
| Drop shadows & glows     | Creates digital plasticity, not paper            | Hairline `1px` borders                    |
| Glassmorphism / frosted  | Trendy but zero academic precedent               | Opaque White `#FFFFFF` content cards      |
| Dark mode                | Breaks the paper-and-ink metaphor entirely       | Light mode only. No exceptions.           |
| Emoji in UI copy         | Incompatible with academic authority tone        | Prose. Punctuation. Precision.            |

---

## 3. Color System

### 3.1 Palette

```
┌──────────────────────────────────────────────────────────────────┐
│  BACKGROUNDS                                                       │
├──────────────────┬─────────────┬──────────────────────────────────┤
│  Warm Canvas     │  #F6F5F0    │  App background — the "paper"    │
│  White           │  #FFFFFF    │  Cards, inputs, modal surfaces   │
├──────────────────┴─────────────┴──────────────────────────────────┤
│  INK (TEXT)                                                        │
├──────────────────┬─────────────┬──────────────────────────────────┤
│  Fountain Navy   │  #1E2A38    │  H1–H4, bold labels, icon fills  │
│  Muted Slate     │  #5B6470    │  Body copy, helper text          │
├──────────────────┴─────────────┴──────────────────────────────────┤
│  ACCENTS                                                           │
├──────────────────┬─────────────┬──────────────────────────────────┤
│  Classic Navy    │  #2F5D8A    │  Primary buttons, active tabs, links │
│  Forest Green    │  #3F6B4F    │  Success, verified, CLO achieved │
│  Academic Amber  │  #B5872A    │  Pending, warning, in-progress   │
│  Red Ink         │  #B4432E    │  Errors, grading deductions only │
└──────────────────┴─────────────┴──────────────────────────────────┘
```

### 3.2 Usage Rules

#### Background Hierarchy
```
Level 0 (App shell)  →  Warm Canvas  #F6F5F0
Level 1 (Cards)      →  White        #FFFFFF  (1px solid #E0DED7 border)
Level 2 (Inputs)     →  White        #FFFFFF  (1px solid #C8C5BC border at rest)
Level 3 (Active)     →  White        #FFFFFF  (1px solid Classic Navy #2F5D8A border)
```

#### Semantic Color Discipline

| Token          | Hex       | **Use**                                        | **Never Use For**                        |
|----------------|-----------|------------------------------------------------|------------------------------------------|
| Classic Navy   | `#2F5D8A` | CTA buttons, active nav, focus rings, links    | Backgrounds, decorative elements         |
| Forest Green   | `#3F6B4F` | Verified badges, success toasts, CLO met       | Primary actions, info states             |
| Academic Amber | `#B5872A` | Pending submission, in-review, turnaround warn | Destructive actions, success states      |
| Red Ink        | `#B4432E` | Error messages, rubric deductions, form errors | Highlighting, decoration, warnings       |

#### Color Mixing Rule
**Never use two accent colors adjacently.** Accents are semantic signals, not decorative. A Forest Green badge next to an Academic Amber badge is permissible (they carry different meanings); a Classic Navy button next to a Forest Green button is not.

### 3.3 Tints (for backgrounds only)

When a light tinted surface is needed (e.g., a KPI card, a notice block), use a `10%` opacity tint of the relevant accent over White, not a saturated fill:

```
Success background  →  #3F6B4F at 10% opacity  →  approx. #EFF4F1
Warning background  →  #B5872A at 10% opacity  →  approx. #F9F4EB
Error background    →  #B4432E at 10% opacity  →  approx. #F9EBE9
Info background     →  #2F5D8A at 10% opacity  →  approx. #EBF0F6
```

---

## 4. Typography System

### 4.1 Typeface Roles

| Role          | Family            | Weight(s)         | Use Case                                      |
|---------------|-------------------|-------------------|-----------------------------------------------|
| **Display**   | Fraunces          | 700 (Bold)        | Page titles (H1–H2), brand name               |
| **UI Serif**  | Fraunces          | 600 (SemiBold)    | Section headers (H3–H4), card titles          |
| **Body**      | Inter             | 400 / 500 / 600   | All body copy, labels, buttons, nav, captions |
| **Data**      | JetBrains Mono    | 400 / 500         | Metrics, KPI values, course codes, scores     |

#### Why these three:
- **Fraunces** has high stroke contrast and ink-trap details that evoke hand-set letterpress. It signals *academic premium* without feeling decorative.
- **Inter** is optically neutral and tested at every weight at small sizes — ideal for dense UI text, tables, and form labels.
- **JetBrains Mono** carries engineering precision. Numbers set in it feel measured, not approximated. Never use Inter for tabular numeric data.

### 4.2 Type Scale

```
Token       Size    Line-Height  Weight        Family           Use
──────────────────────────────────────────────────────────────────────────
display-xl  36px    44px         700           Fraunces         Landing headers, empty states
display-lg  28px    36px         700           Fraunces         Page titles (H1)
display-md  22px    30px         600           Fraunces         Section titles (H2)
display-sm  18px    26px         600           Fraunces         Card titles, dialogs (H3)
body-lg     16px    24px         400/500       Inter            Primary body text
body-md     14px    22px         400           Inter            Secondary body, captions
body-sm     12px    18px         400           Inter            Labels, helper text, tooltips
label-caps  11px    16px         600 uppercase Inter            Table headers, eyebrows
data-lg     24px    30px         500           JetBrains Mono   KPI primary values
data-md     16px    22px         400           JetBrains Mono   Score displays, counters
data-sm     13px    18px         400           JetBrains Mono   Course codes, IDs
```

### 4.3 Letter Spacing

```
Fraunces headings     →  letter-spacing: -0.02em  (tight, authoritative)
Inter body            →  letter-spacing: 0         (neutral)
Inter label-caps      →  letter-spacing: +0.08em  (caps need air)
JetBrains Mono        →  letter-spacing: 0         (monospaced, already spaced)
```

### 4.4 Type Hierarchy Example: Course Card

```
Course Title          → display-sm  / Fraunces 600 / Fountain Navy #1E2A38
Course Code           → data-sm     / JetBrains Mono 400 / Muted Slate #5B6470
Semester / Meta       → body-sm     / Inter 400 / Muted Slate #5B6470
Student Count         → body-sm     / Inter 500 / Fountain Navy #1E2A38
```

---

## 5. Spacing & Layout

### 5.1 Spatial Scale

ProfessorOS uses a **base-4 spacing unit** system. All padding, margin, and gap values must be multiples of 4.

```
4px   →  xs   (icon padding, tight inline gaps)
8px   →  sm   (between label and input)
12px  →  md   (inner card padding compact)
16px  →  lg   (standard inner card padding)
24px  →  xl   (section gap, card-to-card gap)
32px  →  2xl  (major section separators)
40px  →  3xl  (page top padding)
48px  →  4xl  (between page-level sections on desktop)
```

### 5.2 Border System

**No shadows. Depth = Borders.**

```
Hairline (default)    →  1px solid #E0DED7   (card borders, dividers, table rows)
Interactive           →  1px solid #C8C5BC   (input at rest)
Active / Focused      →  1.5px solid #2F5D8A (focused input, selected tab)
Destructive           →  1px solid #B4432E   (error input state)
```

**Border radius:**
```
Input fields          →  8px
Buttons               →  8px
Cards / Panels        →  8px
Badges / Chips        →  4px
Avatar circles        →  50%
Modals (mobile)       →  16px top corners only
```

> **Rule:** Radius above `16px` anywhere except mobile modals is a design error. ProfessorOS is not a consumer app; it is not bubbly.

### 5.3 Web Layout: The Ledger Rail

```
┌───────┬──────────────────────────────────────────────────────────┐
│       │                                                            │
│  72px │              Content Area                                 │
│       │              Max-width: 1200px                            │
│ Rail  │              Padding: 40px left/right                     │
│       │                                                            │
│ icons │              Grid: 12-column, 24px gutter                 │
│  only │                                                            │
│       │                                                            │
└───────┴──────────────────────────────────────────────────────────┘
```

- The Rail is `72px` wide, icon-only, no labels.
- Rail background: White `#FFFFFF` with a single `1px` right border in `#E0DED7`.
- Active nav icon: Classic Navy `#2F5D8A` fill with a `3px` left indicator bar.
- Inactive nav icon: Muted Slate `#5B6470`.

### 5.4 Mobile Layout

- Bottom nav bar: `56px` tall, White background, `1px` top border in `#E0DED7`.
- Nav icons: `24px`, same active/inactive color rules as web.
- Page padding: `16px` horizontal throughout.
- Cards: full-width, no side gaps — the canvas *is* the background.

---

## 6. Component Library

### 6.1 Buttons

#### Primary Button (CTA)
```
Background    →  Classic Navy #2F5D8A
Text          →  White #FFFFFF / Inter 600 / 15px
Border-radius →  8px
Padding       →  12px vertical · 24px horizontal
Hover         →  background #264E78 (10% darker, no transition >150ms)
Active        →  background #1E3D5E
Disabled      →  background #C8C5BC, text #8A8E93, cursor: not-allowed
```

**Never:** gradient fills, icon-only primary buttons, rounded-pill shape.

#### Secondary Button (Outline)
```
Background    →  transparent
Border        →  1px solid #2F5D8A
Text          →  Classic Navy #2F5D8A / Inter 600 / 15px
Hover         →  background #EBF0F6 (Classic Navy 10% tint)
```

#### Destructive Button
```
Background    →  Red Ink #B4432E
Text          →  White
Use for       →  Delete course, Remove student. Gate with confirmation dialog.
```

#### Ghost / Text Button
```
Background    →  transparent
Text          →  Classic Navy #2F5D8A / Inter 500
Underline     →  none at rest; underline on hover
Use for       →  "Forgot password?", "Sign up", inline contextual actions
```

---

### 6.2 Input Fields

```
At rest:
  Background    →  White #FFFFFF
  Border        →  1px solid #C8C5BC
  Text          →  Fountain Navy #1E2A38 / Inter 400 / 15px
  Placeholder   →  Muted Slate #5B6470 / Inter 400 / 15px

Focused:
  Border        →  1.5px solid Classic Navy #2F5D8A
  No background change. No glow. No shadow.

Error:
  Border        →  1px solid Red Ink #B4432E
  Helper text   →  Red Ink #B4432E / Inter 400 / 12px, below field

Disabled:
  Background    →  Warm Canvas #F6F5F0
  Border        →  1px solid #E0DED7
  Text          →  #8A8E93
```

**Labels** always sit above the field, never as floating labels. Label: `Inter 500 / 13px / Fountain Navy #1E2A38`.

---

### 6.3 Cards

Cards are the primary content container. They are always White on the Warm Canvas background.

```
Background    →  White #FFFFFF
Border        →  1px solid #E0DED7
Border-radius →  8px
Padding       →  24px
Shadow        →  none. Ever.
```

**Card Variants:**

- **KPI Card** (Account profile, TA dashboard): Internal grid of `label-caps` + `data-lg`. Icon in relevant accent color. No decorative fills.
- **List Row Card** (Course Ledger): Full-width, `16px` vertical padding, hairline bottom border as divider. No outer card wrapper for lists — the list itself is the card.
- **Dialog / Modal Card**: `max-width: 480px`, centered, `border-radius: 8px`, backdrop `rgba(0,0,0,0.35)`.

---

### 6.4 Segmented Selector (Role Picker)

Used on the registration screen for Professor / Student / TA selection.

```
Container     →  White, 1px solid #C8C5BC, border-radius 8px, no gaps between segments
Selected      →  background Warm Canvas #F6F5F0, border 1.5px Classic Navy #2F5D8A,
                 text Fountain Navy #1E2A38 / Inter 600
Unselected    →  background White, text Muted Slate #5B6470 / Inter 400
```

---

### 6.5 Badges & Status Chips

```
Structure     →  4px border-radius, 6px vertical padding, 10px horizontal padding
               Inter 500 / 12px, uppercase

Verified      →  Forest Green #3F6B4F text · #EFF4F1 background
Pending       →  Academic Amber #B5872A text · #F9F4EB background
Error/Late    →  Red Ink #B4432E text · #F9EBE9 background
Neutral/Role  →  Fountain Navy #1E2A38 text · #EDECEA background
```

---

### 6.6 Tables & Data Rows

Used in the User Management admin screen and the analytics dashboard.

```
Header row    →  Warm Canvas #F6F5F0 background, label-caps typography, 1px bottom border
Body rows     →  White background, 1px bottom border #E0DED7
Row hover     →  background #F9F8F5 (very subtle, no transition)
Cell text     →  body-md / Inter 400 / Fountain Navy
Numeric cells →  data-sm / JetBrains Mono / right-aligned
```

**No striped rows.** Use the hairline borders instead. Striping is a spreadsheet pattern; this is a ledger.

---

### 6.7 Tabs

```
Active tab    →  Fountain Navy text / Inter 600 / 2px bottom border in Classic Navy
Inactive tab  →  Muted Slate text / Inter 400
Divider       →  1px solid #E0DED7 below the full tab bar
```

Used on Course Ledger (Active / Archived), Course Detail screens.

---

### 6.8 Toast / Notification Banners

Always appear at the top of the screen, full-width on mobile, right-aligned on desktop (`320px` wide).

```
Success       →  Forest Green left border (4px), Forest Green icon, body-md text
Warning       →  Academic Amber left border, Amber icon
Error         →  Red Ink left border, Red Ink icon
Background    →  White #FFFFFF, 1px border in the accent color
Shadow        →  none
Duration      →  Auto-dismiss at 4 seconds; do not stack more than 2
```

---

## 7. Iconography

### 7.1 Icon Set

Use a **single icon library** throughout. Recommended: **Lucide** (open source, clean, consistent stroke weight). Never mix icon families.

```
Stroke weight →  1.5px
Size          →  16px (inline), 20px (nav), 24px (feature icons), 32px (empty states)
Color         →  Inherit from context. Never a different accent from the surrounding element.
```

### 7.2 Icon-Only Rules

- Icon-only navigation (Ledger Rail): always accompanied by a `title` attribute for accessibility.
- Icon-only buttons: use only for clearly universal affordances (edit pencil, close X, visibility toggle). Otherwise pair with a text label.
- Feature icons in KPI cards: `24px`, colored in the relevant semantic accent (`Forest Green` for compliance, `Academic Amber` for AI speed, etc.)

### 7.3 Avoid

- Emoji as icons or status indicators.
- Filled icon variants mixed with outline variants.
- Animated icons (spinning loaders are acceptable; bouncing icons are not).

---

## 8. Platform Adaptations

### 8.1 Web — Ledger Rail

| Element               | Specification                                      |
|-----------------------|----------------------------------------------------|
| Rail width            | 72px fixed                                         |
| Rail background       | White `#FFFFFF`                                    |
| Rail right border     | 1px solid `#E0DED7`                                |
| Nav icons             | 20px, Muted Slate at rest, Classic Navy when active|
| Active indicator      | 3px left bar, Classic Navy, full icon row height   |
| Branding mark         | Top of rail: 40px square, Classic Navy background, white mortarboard icon |
| Content max-width     | 1200px, centered in remaining space                |

### 8.2 Mobile — Bottom Navigation

| Element               | Specification                                      |
|-----------------------|----------------------------------------------------|
| Bar height            | 56px                                               |
| Background            | White `#FFFFFF`                                    |
| Top border            | 1px solid `#E0DED7`                                |
| Icons                 | 24px, same active/inactive rules                   |
| Safe area             | Respects iOS/Android bottom safe area insets       |
| Labels                | None. Icons only.                                  |

### 8.3 Responsive Breakpoints

```
Mobile       <  600px    Single column, 16px margins
Tablet       600–900px   Adaptive, 24px margins, Rail collapses to bottom nav
Desktop      > 900px     Ledger Rail visible, 12-column grid, 40px margins
Wide         > 1440px    Content max-width 1200px, canvas fills remaining space
```

### 8.4 Mobile-Specific Components

The **Forgot Password** card (Image 4) demonstrates the mobile modal pattern:
- White card with `16px` border-radius on all corners (centered, floating)
- Warm Canvas gradient background (acceptable only as the fullscreen backdrop for auth-flow cards on mobile, not inside the app)
- Icon placeholder area: `48px` height, Warm Canvas tinted block — used exclusively on auth flows as a visual anchor

---

## 9. Motion & Interaction

### 9.1 Principles

ProfessorOS moves **like a professor turning a page** — deliberate, unhurried, precise. Not like a consumer app eager to delight.

### 9.2 Timing

```
Micro (hover, focus ring)   →  100–150ms, ease-out
Transition (modal open)     →  200ms, ease-out
Page navigation             →  No animation. Instant.
Toast enter                 →  200ms slide-in from top/right, ease-out
Toast exit                  →  150ms fade-out
```

### 9.3 Never Animate

- Page backgrounds or canvas color
- Typography size or weight
- Border thickness on hover
- Any element the user didn't trigger

### 9.4 Loading States

- Skeleton screens only — same color as the card background with a `#E0DED7` placeholder shape. No animated shimmer (it is decorative noise).
- Spinner: `20px`, Classic Navy `#2F5D8A`, `1.5px` stroke circle with a 90° arc. Rotation `600ms` linear infinite.

---

## 10. Tone of Voice & Copywriting

### 10.1 Voice Attributes

| Attribute    | ProfessorOS Does                    | ProfessorOS Never Does              |
|--------------|-------------------------------------|--------------------------------------|
| Register     | Calm, precise, academic             | Hype, cheerleading, startup jargon  |
| Confidence   | States facts plainly                | Hedges with "try" or "maybe"        |
| Warmth       | Present but restrained              | Casual, slang, emoji                |
| Authority     | Earned by clarity                   | Asserted by exclamation marks       |

### 10.2 Interface Microcopy Guidelines

**Buttons:** Active verb + object. Sentence case.
```
✓  Create Course       ✗  CREATE COURSE!
✓  Send Reset Link     ✗  Submit
✓  Save Changes        ✗  Okay
✓  Remove Student      ✗  Delete? Are you sure?
```

**Titles & Headers:** Noun phrases, not questions.
```
✓  Course Ledger       ✗  Your Courses
✓  Account Settings    ✗  Manage Your Profile
✓  Needs Grading       ✗  Things To Grade
```

**Empty States:** Name the action, not the absence.
```
✓  "No assignments yet. Create your first to begin evaluating students."
✗  "Nothing here!"
```

**Error Messages:** Specific cause + specific remedy.
```
✓  "This email is already registered. Sign in or use a different address."
✗  "Something went wrong. Please try again."
```

**Subtitles / Descriptors (used below page H1):**
```
✓  "Manage offerings, HEC rubrics & student cohorts."  (Course Ledger)
✓  "Enter your email and we'll send you a reset link." (Forgot Password)
```
Keep to one sentence. No period if it reads as a command; period if it reads as prose.

### 10.3 Terminology Glossary

These terms are canonical. Use them consistently in UI and documentation.

| Use This               | Not This                        |
|------------------------|----------------------------------|
| Course Ledger          | My Courses / Course List        |
| Cohort                 | Class / Batch                   |
| Submission             | Assignment / Work / Upload      |
| Grading Rubric         | Marking Scheme / Score Sheet    |
| CLO                    | Learning Outcome / Objective    |
| HEC Compliance Score   | Compliance Rating / HEC Score   |
| SpeedGrader            | Grading View / Review Panel     |
| At-Risk Students       | Failing Students / Low Scorers  |
| Verified Academic      | Approved / Confirmed            |

### 10.4 Metric Labels (KPI Cards)

KPI labels use **JetBrains Mono** for the value and **Inter label-caps** for the label. The label describes the data, not the metric type.

```
✓  "4 Active"          under "Courses Taught"
✓  "142 Cohort"        under "Students Evaluated"
✓  "98.4%"             under "HEC Compliance Score"
✓  "1.8 min / submission" under "AI Evaluation Speed"
```

Note the pattern: **number + unit/qualifier** in JetBrains Mono; **human label** in label-caps Inter above.

---

## 11. Do's & Don'ts

### ✓ Do

- Use `1px` borders to create depth. Let them do the structural work.
- Set all numeric data in JetBrains Mono — even inside prose if it's a measured value.
- Use Forest Green for anything that represents completion, compliance, or verification.
- Keep the Ledger Rail icon-only. Navigation labels add visual weight that competes with content.
- Gate all destructive actions (delete, remove, archive) with a confirmation dialog using the exact Destructive Button component.
- Preserve whitespace. If a section feels empty, that is a feature, not a bug.
- Use Fraunces exclusively for headings that are `18px` or larger.

### ✗ Don't

- Add drop shadows to any surface. If you feel the need for a shadow, you need a border.
- Use `border-radius` greater than `16px` inside the app (auth modal backs on mobile being the single exception).
- Mix accent colors without semantic justification. Academic Amber next to Classic Navy buttons is noise, not design.
- Use `font-weight: 800` or `900` anywhere. Maximum weight is `700` (Fraunces display only).
- Animate page transitions. Page navigation is instant — a mark of precision, not laziness.
- Write placeholder text that mimics real data (e.g., "FASDUIFR" is clearly test data — in production, use "e.g., CS101").
- Use percentage-based font-sizes. Use the explicit scale above.
- Introduce a fourth typeface for any reason.
- Apply Dark Mode styles. There is no dark mode. If a component library auto-applies one, override it.

---

## 12. Accessibility Standards

ProfessorOS is used in academic environments where accessibility is not optional.

### 12.1 Color Contrast

All text must meet **WCAG AA** minimum. Recommended targets:

| Foreground        | Background       | Ratio  | Pass?  |
|-------------------|------------------|--------|--------|
| Fountain Navy `#1E2A38` | Warm Canvas `#F6F5F0` | ~11:1 | ✓ AAA |
| Muted Slate `#5B6470`   | White `#FFFFFF`       | ~5.2:1 | ✓ AA  |
| White `#FFFFFF`         | Classic Navy `#2F5D8A` | ~6.8:1 | ✓ AA  |
| White `#FFFFFF`         | Forest Green `#3F6B4F` | ~5.1:1 | ✓ AA  |
| White `#FFFFFF`         | Red Ink `#B4432E`     | ~4.6:1 | ✓ AA  |

**Never use Academic Amber `#B5872A` as text on White.** It fails AA at body size (~2.9:1). Use it only as a background tint or icon color.

### 12.2 Focus States

```
All interactive elements →  2px offset focus ring, Classic Navy #2F5D8A
Do not suppress :focus-visible with outline: none
```

### 12.3 Touch Targets (Mobile)

All tappable elements: minimum `44×44px` hit area, even if the visual is smaller.

### 12.4 ARIA & Semantics

- All icon-only buttons must have `aria-label`.
- All icon-only nav items must have `title` attributes.
- Status badges must use `role="status"` where they update dynamically.
- The SpeedGrader rubric grid must be accessible via keyboard. Each rubric cell should be focusable and triggerable with `Enter`/`Space`.

### 12.5 Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  * {
    transition-duration: 0ms !important;
    animation-duration: 0ms !important;
  }
}
```

Implement this globally. ProfessorOS's minimal animation philosophy means this has negligible UX impact.

---

## Appendix A: Quick Reference Card

```
┌──────────────────────────────────────────────────────────┐
│  PROFESSOROR — MARGINALIA QUICK REF                       │
├──────────────────────────────────────────────────────────┤
│  CANVAS    #F6F5F0   App background                      │
│  CARD      #FFFFFF   All content surfaces                │
│  INK       #1E2A38   Primary text & headings             │
│  SLATE     #5B6470   Secondary / helper text             │
│  NAVY      #2F5D8A   Buttons, active, links              │
│  GREEN     #3F6B4F   Success, verified, CLO met          │
│  AMBER     #B5872A   Pending, warning                    │
│  RED       #B4432E   Errors, deductions                  │
├──────────────────────────────────────────────────────────┤
│  DISPLAY   Fraunces 700 / 600                            │
│  BODY      Inter 400 / 500 / 600                         │
│  DATA      JetBrains Mono 400 / 500                      │
├──────────────────────────────────────────────────────────┤
│  RADIUS    8px cards/buttons · 4px chips · 50% avatar    │
│  BORDERS   1px solid #E0DED7 — no shadows, ever          │
│  SPACING   Base-4 unit: 4 / 8 / 12 / 16 / 24 / 32 / 48  │
├──────────────────────────────────────────────────────────┤
│  MOTION    100-200ms ease-out · No page transitions      │
│  A11Y      WCAG AA minimum · 44px touch targets          │
│  MODE      Light only. No dark mode.                     │
└──────────────────────────────────────────────────────────┘
```

---
