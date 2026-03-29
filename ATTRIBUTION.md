# Attribution

This project includes forked and adapted agent prompts from the following open-source Claude Code plugins:

## pr-review-toolkit — Anthropic

- **License**: MIT
- **Agents adapted**: code-reviewer → `code`, code-simplifier → `simplify`, comment-analyzer → `docs`, pr-test-analyzer → `tests`, silent-failure-hunter → `errors`, type-design-analyzer → `types`
- **Changes**: Removed project-specific references (Daisy, logForDebugging, errorIds.ts), generalized for universal use, enhanced code-simplifier with additional anti-patterns, extended comment-analyzer to cover project documentation.

## security-scanning — Seth Hobson (seth@major7apps.com)

- **License**: MIT (v1.3.0)
- **Agent adapted**: security-auditor → `security`
- **Changes**: Trimmed from full DevSecOps/compliance audit (~155 lines) to PR-scoped security review. Removed SIEM/SOAR, compliance frameworks, quantum crypto, incident response. Extended with dependency review and infrastructure misconfiguration detection.

## systems-programming — Seth Hobson (seth@major7apps.com)

- **License**: MIT (v1.2.1)
- **Agents used as reference**: golang-pro → `go`, rust-pro → `rust`
- **Changes**: Extracted language-specific review patterns from general-purpose coding agents. Rewritten as PR review prompts focused on anti-patterns and idiom violations.

## python-development — Seth Hobson (seth@major7apps.com)

- **License**: MIT (v1.2.1)
- **Agent used as reference**: python-pro → `python`
- **Changes**: Extracted Python review patterns. Rewritten as PR review prompt.

## javascript-typescript — Seth Hobson (seth@major7apps.com)

- **License**: MIT (v1.2.1)
- **Agents used as reference**: javascript-pro → `javascript`, typescript-pro → `typescript`
- **Changes**: Significantly expanded from thin source agents (~30-40 lines). Rewritten as comprehensive PR review prompts.

## jvm-languages — Seth Hobson (seth@major7apps.com)

- **License**: MIT
- **Agents used as reference**: java-pro → `java`, csharp-pro → `csharp`
- **Changes**: Extracted review patterns. Rewritten as PR review prompts.

## blockchain-web3 — Seth Hobson (seth@major7apps.com)

- **License**: MIT (v1.2.1)
- **Agent used as reference**: blockchain-developer + solidity-security skill → `web3`
- **Changes**: Extracted security review patterns from full development agent. Combined with solidity-security skill. Focused on PR-scoped review (Solidity, Anchor/Solana, web3 integration).

## Original Work

The following are original creations with no upstream source:

- `pr-swarm` — Orchestrator (evolved from personal watch-pr skill)
- `pr-swarm-grade` — Grading system (evolved from personal grade-review skill)
- `dry` — DRY/reuse analysis
- `efficiency` — Performance and efficiency review
- `api` — API breaking change detection
- `frontend` — Frontend UI + accessibility review
- `kotlin` — Kotlin review (no source agent existed)
- `swift` — Swift review (no source agent existed)
