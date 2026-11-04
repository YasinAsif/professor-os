# Demo QA Suite

A set of skills for coding agents (Claude Code, Claude.ai skills, or any agent that reads SKILL.md files) that audits a project before a demo, viva, or pitch, finds bugs using different tester personas and scenario drills, fixes what matters, and writes one readiness report.

## What is inside

Hub (start here)
- `demo-readiness-qa`: recon, project profile, run order, merge, fix loop, hardening, final report. Also holds `shared/` (severity scale, finding template, project profile template, report format).

Personas (who is testing)
- `persona-first-timer`
- `persona-attacker`
- `persona-power-user`
- `persona-examiner`
- `persona-client-investor`
- `persona-tech-lead`
- `persona-low-end-user`
- `persona-chaos-engineer`

Scenarios (what is happening)
- `scenario-demo-disasters`
- `scenario-role-journeys`
- `scenario-fresh-machine`
- `scenario-ai-failures`
- `scenario-class-load`
- `scenario-time-and-dates`
- `scenario-countdown`

## Install

Skills are installed as flat folders. Copy ALL the folders in this suite next to each other.

- Claude Code (project): `.claude/skills/`
- Claude Code (all projects): `~/.claude/skills/`

Keep the folder names exactly as they are. The persona and scenario skills point to `../demo-readiness-qa/shared/`, so `demo-readiness-qa` must sit beside them.

## Use

Just tell the agent something like:
- "Make my project demo ready. Demo is on Friday."
- "Run the demo QA suite on this project."
- "Act like a viva examiner and find the questions I cannot answer."
- "Demo is tomorrow, what do I check?"

You can also call a single skill, for example the attacker persona or the AI failures scenario.

## What gets created in your project

```
qa/
  project-profile.md
  findings/          one file per persona or scenario
  bug-list.md        merged and ranked
  viva-prep.md       from the examiner
  demo-disaster-plan.md
  countdown-checklist.md
  DEMO-READINESS-REPORT.md
```

Add `qa/` to your commit if you want to keep the history, or to `.gitignore` if you do not.

## Limits (be honest with yourself)

- Without a browser tool (Playwright or a browser MCP), the first-timer, low-end user, and role journey checks are only code-traced. The skills say so in their findings.
- Persona skills are structured thinking, not real people. Give the app to one real person for 10 minutes too.
- The examiner is much stronger when it can read your actual report, docs, and results.
- Never trust an agent's "all clear" without running the golden path yourself once.
