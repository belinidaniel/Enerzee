---
name: no_auto_commit
description: Never commit without explicit user approval — user wants to review diffs first
type: feedback
---

Never create git commits without the user explicitly asking for it.

**Why:** User wants to review diffs before any commit is made.

**How to apply:** After making file changes, stop. Do not run `git add` or `git commit`. Only commit when the user says so (e.g., "pode commitar", "faz o commit", "commit isso").
