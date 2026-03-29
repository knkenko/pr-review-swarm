---
name: pr-swarm-grade
description: "Grade fix quality after /pr-swarm — cross-reference findings against diff, produce letter-grade report card."
user-invocable: true
---

# PR Swarm Grade — Fix Pass Auditor

Audit fix commits against review findings and produce a graded report card. Use after `/pr-swarm` fix pass to QA the fixes.

## Invocation

```
/pr-swarm-grade        — detect PR from current branch
/pr-swarm-grade 19     — grade fixes for PR #19
```

---

## Phase 1 — Locate Artifacts

### 1a. Identify the PR

- If an argument is provided, use it as `PR_NUMBER`.
- Otherwise, detect from current branch: `gh pr view --json number --jq '.number'`.
- If neither works → STOP: "No PR found. Usage: `/pr-swarm-grade [PR_NUMBER]`"

### 1b. Read review state

```bash
REVIEW_DIR="docs/reviews/PR-${PR_NUMBER}"
```

- Read `${REVIEW_DIR}/_state.json` → extract `pr_number`, `head_sha`, `pr_title`, `agents`, `compiled`.
- If `_state.json` doesn't exist → STOP: "No review found for PR #${PR_NUMBER}. Run `/pr-swarm` first."
- If `compiled` is false → STOP: "Review for PR #${PR_NUMBER} hasn't been compiled yet."

### 1c. Read compiled report

- Read `${REVIEW_DIR}/compiled-report.md`.
- Parse into a structured list of findings. Each finding has:
  - **Number** (sequential)
  - **Category**: `Must Fix`, `Suggestions`, or `Nitpicks` — from section header
  - **Location**: file:line reference
  - **Title**: short description
  - **Agents**: which review agents flagged it
  - **Description**: full finding text

### 1d. Get fix commits

```bash
HEAD_SHA=<head_sha from _state.json>
git log ${HEAD_SHA}...HEAD --oneline
```

- If no commits → findings default to MISS, but fixes comment can still yield SKIP-OK/SKIP-BAD.
- Store the commit list.

### 1e. Get the diff

```bash
git diff ${HEAD_SHA}...HEAD
```

- If PR is merged, check if `HEAD_SHA` is reachable. If not, try merge commit.
- Store full diff for cross-referencing.

### 1f. Find "Review Fixes Applied" comment

```bash
gh pr view ${PR_NUMBER} --json comments --jq '.comments[].body'
```

- Look for comment starting with `## Review Fixes Applied`.
- Parse **Fixed** and **Skipped** lists.
- If no such comment → warn: "No 'Review Fixes Applied' comment found. Grading from diff only."

---

## Phase 2 — Cross-Reference

For **each finding** from the compiled report, determine a verdict:

### Verdict Criteria

| Verdict | Criteria |
|---------|----------|
| **PASS** | Diff clearly addresses the finding. Code change matches the recommended fix. |
| **PARTIAL** | Diff touches relevant code but doesn't fully address the finding. |
| **MISS** | Finding not addressed in diff at all. |
| **REGRESSION** | Diff introduces a new issue in the area the finding referenced. |
| **SKIP-OK** | Finding explicitly skipped with reasonable justification. |
| **SKIP-BAD** | Finding skipped but justification is weak or finding was a Must Fix. |

### Cross-Reference Process

For each finding:

1. **Check the diff**: Does it contain changes to the referenced file(s) and line range(s)?
2. **Check the fixes comment**: Is this finding in "Fixed" or "Skipped"?
3. **Check for dishonesty**: If fixes comment claims "Fixed" but diff doesn't support it → **Dishonest Claim**.
4. **Check for regressions**: If diff changes relevant code but introduces new problems → **REGRESSION**.
5. **Assess fix quality** (PASS and PARTIAL only): Critique the approach, assign quality tag:

### Quality Tags (PASS and PARTIAL only)

| Tag | Meaning |
|-----|---------|
| **Excellent** | Ideal fix — correct approach, clean implementation, handles edge cases. |
| **Good** | Solid fix — correct and reasonable. Default for clean PASS. |
| **Adequate** | Gets the job done but could be better. |
| **Minimal** | Bare minimum — technically addresses finding but cuts corners. |
| **Over-engineered** | Correct but unnecessarily complex for what was needed. |

### Flags

- **Dishonest Claim**: Fixes comment says fixed, but diff contradicts.
- **Proactive Fix**: Something fixed that wasn't in findings (bonus credit).
- **Undocumented Skip**: Finding not in diff AND not in fixes comment.

---

## Phase 3 — Grade

### Per-Finding Scoring

| Verdict | Base Score |
|---------|-----------|
| PASS | 100 |
| PARTIAL | 60 |
| SKIP-OK | 50 |
| MISS | 0 |
| SKIP-BAD | 0 |
| REGRESSION | -50 |

### Category Weights

| Category | Weight |
|----------|--------|
| Must Fix | 3x |
| Suggestions | 1x |
| Nitpicks | 0.5x |

### Score Calculation

```
weighted_score = sum(finding_score * category_weight) for each finding
max_possible = sum(100 * category_weight) for each finding
raw_percentage = (weighted_score / max_possible) * 100
```

### Modifiers (applied to final percentage)

| Modifier | Points | Condition |
|----------|--------|-----------|
| Proactive fixes | +5 (cap +10) | Each fix beyond what was flagged |
| Regression | -10 | Each REGRESSION verdict (stacks) |
| Dishonest claim | -5 | Each dishonest claim (stacks) |

### Letter Grade Scale

| Grade | Range |
|-------|-------|
| A+ | 97-100 |
| A | 93-96 |
| A- | 90-92 |
| B+ | 87-89 |
| B | 83-86 |
| B- | 80-82 |
| C+ | 77-79 |
| C | 73-76 |
| C- | 70-72 |
| D | 60-69 |
| F | Below 60 |

Final score clamped to 0-100 after modifiers.

---

## Phase 4 — Report Card

Write to `${REVIEW_DIR}/grade-report.md` and present in conversation. Do NOT post to PR.

### Output Format

```markdown
## Grade Report — PR #${PR_NUMBER}: ${PR_TITLE}

**Overall: ${LETTER_GRADE} (${SCORE}/100)**

| Category     | Addressed | Total | Score |
|--------------|-----------|-------|-------|
| Must Fix     | X/Y       | Y     | Z%    |
| Suggestions  | X/Y       | Y     | Z%    |
| Nitpicks     | X/Y       | Y     | Z%    |

### Must Fix
1. **${VERDICT}** · ${QUALITY} — `${location}` — ${title}
   _What changed:_ ${factual description}
   _Feedback:_ ${opinionated quality assessment}

### Suggestions
...

### Nitpicks
...

### Flags
- **Dishonest claim**: Finding #${N} claimed fixed but diff shows ${what}.
- **Proactive fix**: ${description}.
- **Undocumented skip**: Finding #${N} not addressed and not mentioned.

(Omit Flags section if none.)

### Summary
${2-3 sentence assessment: quality, strengths, gaps, recommendation}
```

### Formatting Rules

- Number findings matching compiled report numbering.
- Use exact verdict labels: PASS, PARTIAL, MISS, REGRESSION, SKIP-OK, SKIP-BAD.
- "Addressed" counts PASS + PARTIAL + SKIP-OK.
- Every PASS/PARTIAL has two lines:
  - `_What changed:_` — factual, 1 sentence.
  - `_Feedback:_` — **opinionated**, 1-2 sentences. Judgment, not description.
- Quality tags appear after verdict for PASS/PARTIAL only.
- `_Feedback:_` must express judgment. Bad: "Used a typed setter map." Good: "Clean approach — eliminates unsafe cast without over-engineering."

---

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| No review directory | STOP: "No review found for PR #X" |
| Review not compiled | STOP: "Review not compiled yet" |
| No fix commits | Grade from fixes comment skips; all findings MISS unless justified |
| No fixes comment | Warn, grade from diff only, skip dishonesty checks |
| PR already merged | Warn, use merge commit range |
| Empty compiled report | STOP: "No findings to grade" |

---

## Hard Rules

- **Read-only.** Do not modify files, post comments, or push code.
- **Grade every finding.** No finding from compiled report should be skipped.
- **Be honest.** Grade what the diff shows, not what the fixes comment claims.
- **Show your work.** Each verdict must reference specific code changes (or lack thereof).
