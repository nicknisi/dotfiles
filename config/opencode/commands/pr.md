---
description: Full GitHub Flow — generate message, branch, commit, push, create PR
---

Generate a conventional commit message for the staged changes, then execute the full GitHub Flow per the repo's AGENTS.md: create a properly-named feature branch from `main`, commit, push, and create a PR.

## Staged diff

!`git diff --cached`

## Recent commits in this repo (match their tone/scope/format)

!`git log --oneline -15`

## Current branch

!`git branch --show-current`

## Repo-specific guidance (if present below, FOLLOW IT FIRST)

!`cat AGENTS.md 2>/dev/null || echo '(no AGENTS.md found — rely on recent commits + Conventional Commits baseline)'`

## Priority order for message generation

1. **AGENTS.md** repo conventions (branch naming, allowed types/scopes, squash merge) — OVERRIDE everything below.
2. **Recent commit style** — match tone, scope naming, subject phrasing. Imitate the closest recent commit.
3. **Conventional Commits 1.0.0 baseline**:
   - Format: `type(scope): subject`, then optional body and footer.
   - Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `style`, `test`, `perf`, `build`, `ci`.
   - Subject: imperative mood ("add" not "added"), lowercase, no trailing period, <= 72 chars.
   - Body: explain what/why (not how), wrap ~72 cols. Omit if subject suffices.
   - Footer: `BREAKING CHANGE:` or `Closes #123`.

## Execution steps

1. **If nothing is staged**, tell the user to run `git add` first and stop. Do NOT proceed.

2. **Generate the commit message** following the priority order above.

3. **Derive the branch name** from the commit type and scope:
   - Format: `<type>/<scope>` (e.g. `feat/alacritty`, `fix/zsh`, `style/alacritty`)
   - If multiple scopes (e.g. `feat(zsh,config):`), use only the first scope.
   - Branch prefixes: `feat|fix|docs|refactor|chore|perf|test|build|ci|revert|style`

4. **Create the branch from `main`**:
   - If already on `main` or a different remote-tracking branch: `git checkout -b <branch> main`
   - If already on a branch with the same name: skip creation, commit directly.
   - If already on a different uncommitted feature branch: warn the user and ask whether to switch.

5. **Commit**: `git commit -m '<the generated message>'`

6. **Push**: `git push -u origin <branch>`

7. **Create PR**: `gh pr create --title '<commit subject>' --body ''`
   - Use the full commit message subject line as the PR title.
   - AGENTS.md squash merge copies the PR title into the main history — it must be correct.

8. **Report the PR URL** to the user.

## Edge cases

- If `$ARGUMENTS` contains `--dry-run`: only generate the message and branch name, output them in a fenced code block, and stop. Do not branch, commit, push, or create a PR.
- If `$ARGUMENTS` contains `--message-only`: only generate the message, output it in a fenced code block, and stop. Do not branch, commit, push, or create a PR.
- If the branch already exists on the remote, warn before force-pushing.
- The generated commit message must be visible in your final output so the user can review it.

$ARGUMENTS
