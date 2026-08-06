---
name: verify-behavior
description: Verify or reproduce visible product behavior by driving the real UI with pi-computer-use's checked tools, requiring verified expect postconditions and durable state evidence for meaningful UI flows. Use when triage needs visual reproduction, implementation needs behavioral proof, review needs interactive confirmation, or any factory stage asks to verify UI/app behavior.
---

# Verify behavior

Prove or disprove **visible** product behavior for bugs and greenfield features using pi-computer-use. Triage, implementation, and review stages invoke this instead of guessing from code alone.

## Modes

- **`reproduce`** — does the reported bug still happen on baseline? (usually default branch; triage)
- **`verify`** — does the implemented change match expected behavior? (features and fixes; implementation/review)

Infer if unnamed: issue-only → `reproduce`; implementation/PR branch → `verify`.

## Platform contract (do not invent alternatives)

pi-computer-use exposes a **direct, state-scoped tool surface**, not a delegated capability and not raw screen capture. The normal loop:

| Step        | Tools                                                                                                                                                    |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Find**    | `find_roots` returns ranked `@r` roots (desktop windows and CDP browser pages share one forest). `launch_browser` for a managed CDP page.                |
| **Observe** | `observe_ui` captures a root and returns a folded outline, `@e` refs, and a `stateId`. Every later `@e` use requires its owning `stateId`.               |
| **Query**   | `search_ui`, `expand_ui`, `inspect_ui`, and `read_text` query the cached state without re-capturing. Refine broad searches instead of paging matches.    |
| **Act**     | `act_ui` performs checked, transactional steps and returns the successor `stateId`. Attach `expect` when the action has an observable completion signal. |
| **Wait**    | `wait_for` for asynchronous UI changes; `navigate_browser` / `evaluate_browser` only on CDP page states.                                                 |

Consume the successor `stateId` from `act_ui` directly; observe again only after an uncertain external mutation or state eviction.

**Never:**

- Act on `@e` refs without their owning `stateId`, or reuse refs across a rejected/stale state
- Guess coordinates when a semantic `@e` target exists; coordinate clicks are a fallback from a current image-bearing desktop state only
- Build capture pipelines (ffmpeg, x11grab, avfoundation, Playwright video, screencapture CLIs) — evidence comes from checked tool results, not recordings
- Substitute `osascript`/AppleScript/xdotool for the checked tool surface
- Use `navigate_browser`/`evaluate_browser` on native browser windows — those are ordinary desktop UI (`observe_ui` + `act_ui`)
- Race two mutations derived from the same state

## When to use / skip

**Use** for UI, browser, desktop, or other interactive behavior where interacting with the real surface proves the claim.

**Skip** pure backend/CI/text-only work, or when credentials/state are unavailable (report the blocker). If pi-computer-use is not installed or platform permissions (Accessibility / Screen Recording) are missing, stop with an explicit blocker — check with `/computer-use` — do not fake verification.

## PRODUCT.md coverage

When `PRODUCT.md` exists it is the primary source of stories and acceptance criteria:

1. Read it (parent path, `specs/<issue-slug>/PRODUCT.md`, or issue/PR links).
2. Build a checklist of exercisable user-facing stories. Newer issue comments win on conflict.
3. `reproduce`: stories tied to the failure + path to reach it. `verify`: all in-scope stories.
4. No PRODUCT.md → derive stories from the issue.

## Workflow

1. Collect mode, issue/PR, branch/ref, setup commands/URLs, surface hints, PRODUCT.md path/excerpts, and expected behavior.
2. Skip if not visually observable; report why.
3. Start the app (setup commands via bash) and pick the channel: `launch_browser` for pure web apps; `find_roots` + `observe_ui` for native surfaces, OS dialogs, or multi-window flows. Record `Channel: browser | desktop | hybrid` and a one-line why.
4. For each verification unit (checklist story or repro path):
   - Observe the relevant root and locate targets with `search_ui`/`expand_ui`/`inspect_ui`
   - Exercise the critical path end-to-end with `act_ui`, attaching `expect` conditions that encode the acceptance check (`until: "present" | "absent"`, `ref`/`scopeRef` scoping, value checks on exact refs)
   - Use `wait_for` for async transitions instead of polling observations
   - Capture evidence per check: the `expect` verification verdict, successor diffs, and `read_text`/`search_ui` extracts of the decisive UI text or values
5. Multi-story `verify` stays **sequential by default**; overlap live work only across independent processes or CDP pages (the runtime orders same-resource work). Never run two mutations from one state in parallel.
6. Aggregate statuses: confirmed / partially confirmed / not reproduced / verified / partially verified / not verified / blocked.
7. Fold evidence into triage comments, PR bodies, or `review.json`. Do not claim behavioral verification without evidence or an explicit blocker.

### Verification unit shape

```text
Mode: verify | reproduce
Branch/ref: <implementation head or baseline>
Setup: <install/start commands or URL>
Story or repro: <one checklist item or full path>
Checks: <what must be visibly true>
Evidence required:
- act_ui expect verdicts (verified / preexisting / failed) per acceptance check
- Successor diff or observed-state excerpt showing the decisive change
- read_text / search_ui extract of key on-screen text or values
Return: steps taken, observations per check, blockers
```

## Evidence requirements

For every meaningful UI flow:

1. **Verified postconditions** — each acceptance check maps to an `act_ui` `expect` (or `wait_for`) whose verdict is quoted. A `preexisting` verdict means the end state holds but the action is not proven to have caused it — say so; re-drive from a clean state when causality matters.
2. **State evidence** — quote the successor diff or the relevant observed outline/text excerpt (`stateId`, refs, values) proving the before/after change. Long extracts continue via `@o` refs, not screenshots.
3. **Failed-check honesty** — `postcondition_failed` and stale-state errors are findings, not noise; report them verbatim.
4. **PR / issue write-up** — status, story checklist outcomes, and per-check evidence (verdict + decisive UI text/values). Under any image you do post from other tooling, add a concise caption: the UI state/case being verified and what it demonstrates.

A verification that never drove the UI through pi-computer-use tools while the surface was available is **incomplete**.

## Report shape

```text
Behavior verification:
- Mode / change type / channel(s)
- Status / issue-PR / branch-ref
- PRODUCT.md stories: n passed / failed / blocked / not run
- Evidence: expect verdicts per check + state diffs/extracts
- Findings / next step
```

**reproduce** statuses: confirmed | partially confirmed | not reproduced | blocked
**verify** statuses: verified | partially verified | not verified | blocked

## Guardrails

- Drive GUI work through the checked pi-computer-use loop (observe → query → act with `expect`); no unchecked input synthesis
- Every `@e` action carries its owning `stateId`; consume successor states instead of re-observing blindly
- No ffmpeg or external recorders; no osascript/AppleScript substitutes
- Verified `expect`/`wait_for` verdicts required for meaningful flows; observed-state extracts supplement
- `preexisting` is not causal proof; stale-state and `postcondition_failed` results are reported, not retried silently
- CDP tools only on CDP page states; native browser windows are desktop UI
- Features are first-class; PRODUCT.md drives coverage when present
- Sequential by default; overlap only independent resources; no secrets in prompts, extracts, or reports
- No claim of verification without evidence or an explicit blocker

Optional `verify-behavior-local` may specialize setup/surface/channel only — not weaken evidence, privacy, or this contract.
