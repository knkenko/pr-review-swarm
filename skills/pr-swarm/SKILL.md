---
name: pr-swarm
description: "Orchestrate a parallel PR review agent swarm — detect, launch, collect, compile report, fix findings. Crash-resilient."
user-invocable: true
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent]
---

Review the current PR using a parallel agent swarm, then address all findings.
Agent findings persist to `docs/reviews/` so reviews survive session crashes.

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

**HARD GATE: If `has_code`, minimum 3 agents. If `is_docs_only`, minimum 1. A single-agent review is not a review.**

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
- `pr-swarm-code` — general code quality
- `pr-swarm-security` — security + deps + infra

**Run when applicable:**
- `pr-swarm-errors` — if `has_error_handling` or `has_code`
- `pr-swarm-simplify` — if `has_code`
- `pr-swarm-dry` — if `has_code`
- `pr-swarm-docs` — if `has_code` or `is_docs_only`
- `pr-swarm-types` — if `has_types`
- `pr-swarm-tests` — if `has_tests`
- `pr-swarm-efficiency` — if `has_code`
- `pr-swarm-api` — if `has_api`
- `pr-swarm-frontend` — if `has_frontend`
- `pr-swarm-web3` — if `has_web3`

**Language-specific** (auto-select based on detected languages):
- `pr-swarm-python` — if Python detected
- `pr-swarm-typescript` — if TypeScript detected
- `pr-swarm-javascript` — if JavaScript detected
- `pr-swarm-go` — if Go detected
- `pr-swarm-rust` — if Rust detected
- `pr-swarm-java` — if Java detected
- `pr-swarm-csharp` — if C# detected
- `pr-swarm-kotlin` — if Kotlin detected
- `pr-swarm-swift` — if Swift detected

**For each selected agent:**

1. Read the agent's skill file from disk: `~/.claude/skills/{agent-name}/SKILL.md`
   - If not found, fall back to the repo's own `skills/{agent-name}/SKILL.md`
   - If neither exists, skip that agent and note in report
2. Extract the prompt content (everything after the frontmatter `---`)
3. Launch as `general-purpose` Agent with `run_in_background: true` and `model: "opus"`

**Each agent prompt MUST include:**
- The extracted skill prompt
- PR number, branch, base branch, changed files list
- Instruction: `Review ONLY changed files. Use git diff {BASE_BRANCH}...HEAD to see the diff.`
- Self-persistence instruction (below)
- Git safety instruction (below)

**Self-Persistence Instruction (REQUIRED in every agent prompt):**

> After completing your review, you MUST write your findings to `docs/reviews/PR-{NUMBER}/{agent-name}.md` using the Write tool. Format:
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

**Do NOT:**
- Start reading findings before all agents return
- Start compiling the report before all agents return
- Skip ahead to Phase 4 while any agent is running
- Start fixing code while agents are running

**Timeout:** If one agent hasn't returned but all others completed 10+ minutes ago, mark as `failed` and proceed.

**After all agents returned:**
1. List all `*.md` files in `docs/reviews/PR-{NUMBER}/`. Report: "{X}/{N} produced findings."
2. Update `_state.json`: set phase to `compiling`.

## Phase 4: Compile Report

1. **Read all findings from files** — read each `docs/reviews/PR-{NUMBER}/{agent-name}.md` from disk.

2. **De-duplicate:** If multiple agents flag the same file:line for overlapping reasons, consolidate and note which agents flagged it.

3. **Categorize findings:**
   - **Must Fix** — bugs, security issues, correctness problems, broken logic
   - **Suggestions** — improvements, better patterns, performance, readability
   - **Nitpicks** — style, naming, minor preferences

4. **Write compiled report** to `docs/reviews/PR-{NUMBER}/compiled-report.md`

5. **Update `_state.json`:** set phase to `done`, compiled to `true`

6. **Post as PR comment:**
   ```bash
   gh pr comment {NUMBER} --body "$(cat <<'EOF'
   ## PR Review Swarm — Findings

   **Summary:** N files reviewed, M agents ran (list areas)

   **Must Fix (N items)**
   - [ ] `file:line` — [agent] description

   **Suggestions (N items)**
   - [ ] `file:line` — [agent] description

   **Nitpicks (N items)**
   - [ ] `file:line` — [agent] description

   *Agents: {list of agents that ran}*
   EOF
   )"
   ```

7. **Present the report** to the user in conversation.

8. **Ask:** "Want me to address all findings, pick specific items, or skip?"

## Phase 5: Fix Pass (Sequential)

**STOP. Do NOT start fixing until ALL gates pass:**
1. Every agent has returned (Phase 3 complete)
2. Compiled report written (Phase 4 step 4)
3. Findings posted as PR comment (Phase 4 step 6)
4. Report presented to user (Phase 4 step 7)
5. User has responded with their choice (Phase 4 step 8)

**If ANY gate is false, do NOT touch code files.**

### Step 5a: Plan fix order
1. Priority order: must-fix → suggestions → nitpicks
2. Group findings touching same function/block (apply together)
3. Report plan before starting

### Step 5b: Apply fixes sequentially
- Read target file(s) before editing
- Each logical fix or small group = 1 commit with descriptive message
- **Scope guard:** Only change what the finding describes
- **Skip policy:** If fix requires architectural changes beyond scope, skip and document why

### Step 5c: Verify
Run full test suite once after all fixes.
- Pass: proceed to Step 5d
- Fail: identify breaking commit(s), revert, note as "skipped — broke tests"

### Step 5d: Finalize
1. Push all commits
2. Post follow-up PR comment:
   ```bash
   gh pr comment {NUMBER} --body "$(cat <<'EOF'
   ## Review Fixes Applied

   **Fixed:**
   - `file:line` — what was changed and why

   **Skipped (with reason):**
   - item — reason

   *All changes in latest push*
   EOF
   )"
   ```
