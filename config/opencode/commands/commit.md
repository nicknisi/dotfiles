---
description: Generate a conventional commit message from staged changes
---

Generate a conventional commit message for the currently staged changes.

## Staged diff

!`git diff --cached`

## Recent commits in this repo (match their tone/scope/format)

!`git log --oneline -15`

## Repo-specific guidance (if present below, FOLLOW IT FIRST)

!`cat AGENTS.md 2>/dev/null || echo '(no AGENTS.md found — rely on recent commits + Conventional Commits baseline)'`

## Priority order

1. **Repo-specific guidance above** — if AGENTS.md specifies scopes, allowed
   types, PR/squash conventions, or workflow rules, those OVERRIDE everything
   below. If it's silent on a point, fall through.
2. **Recent commit style above** — match the tone, scope naming, subject
   phrasing, and format already used in this repo's history. When in doubt,
   imitate the closest recent commit.
3. **Conventional Commits 1.0.0 baseline** — apply only where #1 and #2 are
   silent:
   - Format: `type(scope): subject`, then optional body and footer.
   - Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `style`, `test`,
     `perf`, `build`, `ci`.
   - `scope` optional, lowercased component name.
   - Subject: imperative mood ("add" not "added"), lowercase, no trailing
     period, <= 72 chars.
   - Body: explain what/why (not how), wrap ~72 cols. Omit if subject suffices.
   - Footer: `BREAKING CHANGE:` notes or refs like `Closes #123`.

## Output

- If nothing is staged, tell me to run `git add` first and stop.
- Output ONLY the commit message in a fenced code block, ready for
  `git commit -m`. Do NOT run `git commit` yourself.
- If the staged change is ambiguous, give 2-3 candidate messages and let me
  pick.

$ARGUMENTS
