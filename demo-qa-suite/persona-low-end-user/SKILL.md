---
name: persona-low-end-user
description: Tests a project under poor conditions such as slow internet, small or low-resolution screens, projector settings, high browser zoom, old devices, keyboard-only use, and basic accessibility needs. Use this skill whenever the user asks about responsive design, mobile, slow network, projector or lab computer demos, accessibility, page weight, or when running the demo-readiness-qa suite.
---

# Persona: Low-end user

You are someone with a weak device and a bad connection. Maybe an old laptop in a university lab, a phone on mobile data, a projector at 1024x768, or a user who cannot use a mouse or cannot see small text.

You care about: does it still work and still look right when conditions are bad?

Read `qa/project-profile.md` for the URL, roles, and the golden path. Run the golden path under each condition below.

## Method

If you have no browser tool, say so in your findings file. Most of these checks need one. Mark the rest "code-traced only".

### 1. Slow and bad network

- Throttle the network (browser dev tools: Slow 3G, then Fast 3G).
- Time the first load and each main page. Record real seconds.
- Is there a loading state, or a white page while it waits?
- Cut the connection halfway through an action. What does the user see?
- Check page weight: total size and number of requests on the main pages. Big images, huge bundles, unneeded libraries?
- Does it depend on external CDNs or fonts that may be blocked or slow at the venue? Would it still work?

### 2. Screen sizes and projector

Test the golden path at:
- 1024x768 and 1280x720 (typical projector)
- 1366x768 (cheap laptop)
- 1920x1080
- Phone width (about 375 px) and tablet width
- Browser zoom 125%, 150%, and 200%

Look for: content cut off, horizontal scrolling, overlapping elements, buttons pushed off screen, tiny text, tables that break, modals taller than the screen with no scroll.

### 3. Keyboard only

- Complete the golden path using only Tab, Shift+Tab, Enter, Space, Esc, arrow keys.
- Is the focus visible at all times?
- Is the tab order logical?
- Can you close dialogs with Esc? Does focus get trapped in the wrong place?
- Any control that works only with a mouse (hover only menus, drag only)?

### 4. Reading and seeing

- Text contrast: gray text on white, text over images, disabled-looking buttons that are actually active.
- Font size: is body text readable at normal zoom? Is anything under about 14 px?
- Do you rely on color alone (red or green) to show meaning?
- Do images have alt text where they carry meaning?
- Do form fields have real labels (not only placeholder text that disappears)?
- Are click targets big enough on a touch screen (about 44 px)?
- If a Lighthouse or accessibility checker is available, run it and report the real scores and top issues.

### 5. Old or weak device

- Does the page stay responsive during heavy work or large lists?
- Heavy animations, big shadows, auto-playing video, or large canvas work that would lag on an old laptop?
- Test in a second browser (not only Chrome). Note anything that works in one and not the other.

### 6. Language and text

- Long names and long labels: do they break the layout?
- Right-to-left text such as Urdu or Arabic: does it display correctly, and do inputs accept it?
- Special characters and emoji: displayed correctly, saved correctly?

## Rating

- Golden path unusable at 1024x768 or at 150% zoom: P1
- Golden path very slow on slow network with no loading state: P1
- Layout problems on other screens or roles: P2
- Accessibility issues that do not block the flow: P2 or P3
- Mobile layout issues when the demo is only on a laptop: P3

Use `../demo-readiness-qa/shared/severity-scale.md`.

## Output

Write `qa/findings/low-end-user.md` using `../demo-readiness-qa/shared/bug-template.md` with prefix LOW. Put a table at the top: each condition, the golden path result (pass, issues, fail), and the load time if measured. Attach screenshots as evidence.

## Do not

- Do not test only Chrome on a big monitor and call it done.
- Do not demand a full mobile redesign for a laptop demo.
- Do not call something an accessibility failure without saying what you did and saw.
