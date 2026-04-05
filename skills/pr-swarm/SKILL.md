---
name: pr-swarm
description: "Orchestrate a parallel PR review agent swarm — detect, launch, collect, compile report, fix findings. Crash-resilient."
user-invocable: true
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent]
---

Review the current PR using a parallel agent swarm, then address all findings.
Agent findings persist to `docs/reviews/` so reviews survive session crashes.

## Single-Agent Mode

If the user specifies agent names, run only those agents instead of auto-detecting:

```
/pr-swarm security          — run only the security agent
/pr-swarm python typescript — run only Python and TypeScript agents
```

Valid agent short names: `api`, `code`, `csharp`, `docs`, `dry`, `efficiency`, `errors`, `frontend`, `go`, `java`, `javascript`, `kotlin`, `python`, `rust`, `security`, `simplify`, `swift`, `tests`, `types`, `typescript`, `web3`.

When in single-agent mode, skip Phase 1 detection flags — just launch the requested agents directly. The rest of the workflow (state, collection, compile, fix) is unchanged.

## Branch Safety

All phases run on the PR branch. NEVER `git checkout main` or switch branches.

## Phase 0: Recovery Check

Before anything else, check for existing review state:

1. Detect the current PR:
   - Run `gh pr view --json number,url,title,baseRefName 2>/dev/null || echo "NO_PR"`
   - If no PR found, ask the user for the PR number or URL
   - Extract `baseRefName` — this is `BASE_BRANCH` for all diffs
   - Verify `gh` CLI is available — if not, STOP: "GitHub CLI (gh) required. Install: https://cli.github.com"

2. Check for existing review state:
   - Run `cat docs/reviews/PR-{NUMBER}/_state.json 2>/dev/null || echo "NO_STATE"`
   - If state exists:
     - Read `_state.json` to get the full list of agents
     - Check which `{agent-name}.md` files exist on disk — these agents completed regardless of what `_state.json` says
     - Compare `HEAD` SHA against `head_sha` in state. If different, warn about changes since last review.
     - Tell user: "Found previous review for PR #{N}. {X}/{Y} agents completed."
     - Ask: "Resume (run remaining agents) or restart fresh?"
     - If **resume**: skip to Phase 2 **Step 2b**. Only launch agents whose file does NOT exist.
     - If **restart**: delete directory and continue normally
   - If no state: continue to Phase 1

## Phase 1: Detect PR and Scope

1. Get changed files and diff:
   - `gh pr diff --name-only 2>/dev/null | head -50`
   - `git diff BASE_BRANCH...HEAD --stat`

2. Set detection flags from changed files:

   - `has_frontend`: .tsx, .jsx, .css, .scss, .vue, .svelte files
   - `has_tests`: *.test.*, *.spec.*, *_test.* files
   - `has_types`: .ts, .tsx files OR .py files with type hints
   - `has_code`: any source files (not just docs/config)
   - `has_error_handling`: files with try/catch, catch blocks, except clauses
   - `has_api`: route/endpoint definitions, OpenAPI specs, GraphQL schemas, protobuf files
   - `has_web3`: .sol files OR files importing ethers, viem, web3.js, @solana/web3.js, anchor
   - `has_security_surface`: auth, API, input handling, env, or config files
   - `has_deps`: package.json, requirements.txt, go.mod, Cargo.toml, Gemfile, build.gradle changes
   - `is_docs_only`: ONLY .md, .txt, .json, or config files

3. Detect primary language(s) by file extension count:
   - `.py` → Python, `.ts/.tsx` → TypeScript, `.js/.jsx` → JavaScript
   - `.go` → Go, `.rs` → Rust, `.java` → Java, `.cs` → C#
   - `.kt/.kts` → Kotlin, `.swift` → Swift, `.sol` → Solidity

4. Inform user: "Running full review on PR #___ (N files changed, areas: ...)"

## Phase 2: Initialize State and Launch Agent Swarm

**HARD GATE: If `has_code`, minimum 3 agents. If `is_docs_only`, minimum 1.**

A single-agent review misses cross-cutting concerns — security issues invisible to a code quality reviewer, duplication invisible to a security reviewer. The value of the swarm is overlapping coverage.

### Step 2a: Create review state

```bash
mkdir -p docs/reviews/PR-{NUMBER}
```

Write `docs/reviews/PR-{NUMBER}/_state.json`:

```json
{
  "pr_number": "{NUMBER}",
  "pr_title": "{TITLE}",
  "branch": "{BRANCH}",
  "base_branch": "{BASE_BRANCH}",
  "head_sha": "{HEAD_SHA}",
  "started_at": "{ISO_TIMESTAMP}",
  "agents": {
    "code": { "status": "pending", "file": null }
  },
  "phase": "launching",
  "compiled": false
}
```

### Step 2b: Select and launch agents

**Agent selection based on detection flags:**

**Always run** (skip only if `is_docs_only`):
- `code` — general code quality
- `security` — security + deps + infra

**Run when applicable:**
- `errors` — if `has_error_handling` or `has_code`
- `simplify` — if `has_code`
- `dry` — if `has_code`
- `docs` — if `has_code` or `is_docs_only`
- `types` — if `has_types`
- `tests` — if `has_tests`
- `efficiency` — if `has_code`
- `api` — if `has_api`
- `frontend` — if `has_frontend`
- `web3` — if `has_web3`

**Language-specific** (auto-select based on detected languages):
- `python` — if Python detected
- `typescript` — if TypeScript detected
- `javascript` — if JavaScript detected
- `go` — if Go detected
- `rust` — if Rust detected
- `java` — if Java detected
- `csharp` — if C# detected
- `kotlin` — if Kotlin detected
- `swift` — if Swift detected

**For each selected agent:**

1. Locate the bundled agents directory. Search in order:
   - `~/.agents/skills/pr-swarm/agents/` (universal path)
   - `~/.claude/skills/pr-swarm/agents/` (Claude Code)
   - `~/.cursor/skills/pr-swarm/agents/` (Cursor)
   - `./skills/pr-swarm/agents/` (local repo fallback)
   - Use the first path that contains `.md` files
2. Read the agent's prompt file: `{agents_dir}/{agent-short-name}.md` (e.g., `agents/security.md`)
3. Extract the prompt content (everything after the frontmatter `---`)
4. Launch as `general-purpose` Agent with `run_in_background: true`

**Each agent prompt MUST include:**
- The extracted skill prompt
- PR number, branch, base branch, changed files list
- Instruction: `Review ONLY changed files. Use git diff {BASE_BRANCH}...HEAD to see the diff.`
- Self-persistence instruction (below)
- Git safety instruction (below)

**Self-Persistence Instruction (REQUIRED in every agent prompt):**

> After completing your review, you MUST write your findings to `docs/reviews/PR-{NUMBER}/{agent-short-name}.md` (e.g., `security.md`, `python.md`) using the Write tool. Format:
> - **Summary** (1-2 sentences)
> - **Must Fix** (bulleted list with `file:line` references)
> - **Suggestions** (bulleted list with `file:line` references)
> - **Nitpicks** (bulleted list with `file:line` references)
> - If no findings in a category, write "None"
>
> Writing this file is your MOST IMPORTANT action — do it before returning.

**Git Safety Instruction (REQUIRED in every agent prompt):**

> Do NOT run `git checkout`, `git switch`, or any command that changes the current branch. You are on the PR branch — stay on it. Use `git diff {BASE_BRANCH}...HEAD` for diffs. Never checkout main.

After dispatching all agents, update `_state.json`: set phase to `collecting`.

## Phase 3: Collect Agent Results

Agents run in background. You are notified as each completes — do NOT poll or sleep.

**As each agent returns:**
1. Report: "{agent-name} completed ({X}/{N} done)"
2. If error/empty output, check if `.md` file exists on disk. Write fallback if needed.
3. Update `_state.json`: set agent status to `completed` or `failed`.

**Do NOT proceed early — wait for all agents.** Compiling a partial report means de-duplication misses cross-agent overlap (agents often flag the same issue differently). Starting fixes while agents run risks editing files an agent is actively reading, corrupting its review.

- Do NOT start reading findings before all agents return
- Do NOT start compiling the report before all agents return
- Do NOT skip ahead to Phase 4 while any agent is running
- Do NOT start fixing code while agents are running

**Timeout:** If one agent hasn't returned but all others completed 10+ minutes ago, mark as `timed_out` and proceed.

**Failed agent retry policy:** If any agent fails or times out, you MUST retry it once before moving on. Re-read the agent prompt file and re-launch. Only after a second failure may you mark it as `failed` and proceed without it. Do NOT silently skip failed agents — every selected agent was selected for a reason and its coverage area will have zero findings if skipped.

**After all agents returned (including retries):**
1. List all `*.md` files in `docs/reviews/PR-{NUMBER}/`. Report: "{X}/{N} produced findings."
2. If any agents failed after retry, warn the user: "Agents {list} failed after retry — their review areas have no coverage."
3. Update `_state.json`: set phase to `compiling`.

## Phase 4: Compile Report

1. **Read all findings from files** — read each `docs/reviews/PR-{NUMBER}/{agent-name}.md` from disk.

2. **De-duplicate:** If multiple agents flag the same file:line for overlapping reasons, consolidate and note which agents flagged it.

3. **Categorize findings:**
   - **Must Fix** — bugs, security issues, correctness problems, broken logic
   - **Suggestions** — improvements, better patterns, performance, readability
   - **Nitpicks** — style, naming, minor preferences

4. **Number every finding sequentially** — assign a single global number (1, 2, 3…) across all categories. Must Fix items come first, then Suggestions, then Nitpicks. This number is the finding's permanent ID and MUST be used consistently in the compiled report, the PR comment, the in-conversation presentation, and the resolution checklist in Phase 5. If the compiled report has 14 findings, they are numbered 1–14 — no gaps, no duplicates.

5. **Write compiled report** to `docs/reviews/PR-{NUMBER}/compiled-report.md`

   The report must list every finding with its number, location, source agent(s), and description. Use this structure:

   ```markdown
   # Compiled Review — PR #{NUMBER}: {TITLE}

   **Summary:** N files reviewed, M agents ran, T total findings

   ## Must Fix (X items)

   **#1** · `file:line` · [agent1, agent2]
   Description of the finding.

   **#2** · `file:line` · [agent1]
   Description of the finding.

   ## Suggestions (Y items)

   **#3** · `file:line` · [agent1]
   Description of the finding.

   ## Nitpicks (Z items)

   **#4** · `file:line` · [agent1]
   Description of the finding.

   ---
   **Total findings: T** (Must Fix: X, Suggestions: Y, Nitpicks: Z)
   ```

   The **Total findings** line at the bottom is a hard requirement — it anchors the count so the resolution checklist in Phase 5 can verify nothing was dropped.

6. **Update `_state.json`:** set phase to `done`, compiled to `true`

7. **Post as PR comment:**
   ```bash
   gh pr comment {NUMBER} --body "$(cat <<'EOF'
   ## PR Review Swarm — Findings

   **Summary:** N files reviewed, M agents ran, T total findings

   **Must Fix (X items)**
   - [ ] #1 · `file:line` — [agent] description
   - [ ] #2 · `file:line` — [agent] description

   **Suggestions (Y items)**
   - [ ] #3 · `file:line` — [agent] description

   **Nitpicks (Z items)**
   - [ ] #4 · `file:line` — [agent] description

   **Total findings: T** (Must Fix: X, Suggestions: Y, Nitpicks: Z)

   *Agents: {list of agents that ran}*
   EOF
   )"
   ```

8. **Present the report** to the user in conversation.

9. **Ask:** "Want me to address all findings, pick specific items, or skip?"

   **Interpreting the user's response:**
   - **"address all" / "fix all" / "all"** → Every finding must be resolved. "Resolved" means the code is changed to address it. The only acceptable exceptions are findings that are genuinely not applicable (the agent's analysis was wrong, or the code doesn't exist). "Intentionally deferred" is NOT allowed when the user says "all" — they are explicitly telling you not to defer. Do not silently downgrade suggestions or nitpicks to deferred. Do not skip items because they seem minor. The user said all and they mean all.
   - **"pick specific items"** → User will list items by number. Only address those.
   - **"skip"** → Do not fix anything.

## Phase 5: Fix Pass (Sequential)

**STOP. Read this entire gate checklist before touching any code file.**

You are not allowed to edit, write, or modify any source file until every single gate below is TRUE. No exceptions. No "I'll present the report after." No "I'll fix this obvious one while waiting." The user has explicitly asked for this workflow — report first, then approval, then fixes. Violating this order means the user sees changes they never approved.

**All five gates must be TRUE:**

1. Every agent has returned or been retried and failed (Phase 3 complete)
2. Compiled report written to disk (Phase 4 step 5)
3. Findings posted as PR comment (Phase 4 step 7)
4. Report presented to user in conversation (Phase 4 step 8)
5. User has responded with their choice — you received an explicit message from the user (Phase 4 step 9)

**If ANY gate is false, do NOT open, edit, or write any code file. Wait.**

### Step 5a: Plan fix order
1. Priority order: must-fix → suggestions → nitpicks
2. Group findings touching same function/block (apply together)
3. Report plan before starting

### Step 5b: Apply fixes sequentially
- Read target file(s) before editing
- Each logical fix or small group = 1 commit with descriptive message
- **Scope guard:** Only change what the finding describes
- **Deferral policy:** You may defer a finding ONLY if the user chose "pick specific items" and did not include it, or if fixing it would require changes to files/systems outside this PR's scope (e.g., database migrations, third-party API changes). Suggestions and nitpicks are not automatically deferrable — they are real findings that the reviewers flagged for a reason. When the user said "address all", treat every category (must-fix, suggestions, nitpicks) with equal obligation.

### Step 5c: Verify
Run full test suite once after all fixes.
- Pass: proceed to Step 5d
- Fail: identify breaking commit(s), revert, note as "skipped — broke tests"

### Step 5d: Resolution checklist

Before pushing, produce a resolution checklist that accounts for EVERY finding in the compiled report. No finding may be omitted — if the compiled report has 14 items, the checklist has 14 entries. Use the same `#N` numbers from the compiled report.

Each finding gets exactly one disposition:
- **fixed** — code was changed to address this finding
- **intentionally deferred** — not addressed in this PR, with a specific reason (ONLY allowed when user did NOT say "address all")
- **not applicable** — the finding was incorrect, or the code it references doesn't exist / was already changed by another fix

Present the checklist to the user in conversation BEFORE pushing. The user must see every item and its disposition. If they object to any disposition, revise before pushing.

**Hard rule:** The total number of items across both sections (Fixed + Unresolved) MUST equal the total findings count from the compiled report. If they don't match, you missed something — go back and account for every item.

### Step 5e: Push and comment

1. Push all commits
2. Post follow-up PR comment using bullet lists — do NOT use markdown tables (they render as broken CSV in many GitHub contexts). Use this exact format:

   ```bash
   gh pr comment {NUMBER} --body "$(cat <<'EOF'
   ## Review Fixes — Resolution Checklist

   ### Fixed (N items)

   - **#1** · Must Fix · `file:line` — description → commit abc1234
   - **#2** · Suggestion · `file:line` — description → commit def5678
   - **#5** · Nitpick · `file:line` — description → commit ghi9012

   ### Unresolved (N items)

   - **#3** · Nitpick · `file:line` — description → **not applicable:** finding was incorrect because X
   - **#4** · Suggestion · `file:line` — description → **deferred:** requires database migration outside PR scope

   **Total: T findings** — X fixed, Y not applicable, Z deferred

   *All changes in latest push*
   EOF
   )"
   ```

   The **Unresolved** section keeps the original `#N` index from the compiled report so the user can instantly cross-reference what was skipped and why. If everything was fixed, write "### Unresolved (0 items)" with "None" underneath — do not omit the section.
