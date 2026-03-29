# pr-review-swarm

Parallel PR review agent swarm for AI coding agents — launches up to 21 specialized reviewers, compiles a de-duplicated report, fixes findings, and grades the fix quality.

Works with Claude Code, Cursor, Windsurf, Codex, Gemini CLI, GitHub Copilot, Amp, Cline, Aider, and 30+ more AI coding agents via [`npx skills add`](https://github.com/vercel-labs/skills).

## Why this exists

Existing PR review tools run one check at a time. You launch them manually, read scattered outputs, fix by hand, and if your session crashes mid-review you start over.

pr-review-swarm fixes this:

- **Parallel agent swarm** — auto-detects what's in the PR (languages, file types, patterns) and launches only the relevant review agents simultaneously
- **Crash-resilient state** — each agent writes its own findings file to `docs/reviews/PR-{N}/`. Session dies? Resume where you left off
- **Compiled report** — de-duplicates findings across agents, categorizes as Must Fix / Suggestions / Nitpicks, posts as a GitHub PR comment
- **Automated fix pass** — sequentially fixes findings with atomic commits, runs tests, reverts breaking changes
- **Grading system** — cross-references the compiled report against actual diff, produces a letter-grade report card with dishonesty detection

## Install

Requires [GitHub CLI](https://cli.github.com) (`gh`) for PR interaction.

```bash
npx skills add knkenko/pr-review-swarm
```

Interactive TUI — auto-detects your AI coding agent, lets you pick which skills to install. Supports 40+ agents including Claude Code, Cursor, Windsurf, Codex, Gemini CLI, GitHub Copilot, and more.

Installs 2 skills: the orchestrator (`pr-swarm`) and the grader (`pr-swarm-grade`). All 21 review agents are bundled inside the orchestrator.

## Usage

### Full review

On a branch with an open PR:

```
/pr-swarm
```

This will:
1. Detect the PR and its changed files
2. Set detection flags (has_frontend, has_tests, has_types, etc.)
3. Launch relevant agents in parallel
4. Collect results and compile a de-duplicated report
5. Post findings as a PR comment
6. Ask if you want to fix findings

### Run specific agents

```
/pr-swarm security          — run only the security agent
/pr-swarm python typescript — run Python and TypeScript agents only
```

### Grade a fix pass

After `/pr-swarm` fixes findings:

```
/pr-swarm-grade
```

Produces a letter-grade report card (A+ through F) by cross-referencing the compiled report against the actual diff. Catches dishonest claims, undocumented skips, and regressions.

## Agents

### Always run
| Agent | What it checks |
|-------|---------------|
| `code` | Code quality, bug detection, project convention compliance |
| `security` | OWASP Top 10, secrets, dependency risks, infrastructure misconfigs, supply chain |

### Conditional (based on PR content)
| Agent | Runs when | What it checks |
|-------|-----------|---------------|
| `errors` | has code | Silent failures, inadequate catch blocks, hidden error paths |
| `simplify` | has code | Unnecessary complexity, redundant state, parameter sprawl, copy-paste |
| `dry` | has code | Cross-file duplication, missed utility reuse |
| `docs` | has code or docs-only | Comment accuracy, stale project documentation |
| `efficiency` | has code | N+1 queries, concurrency bugs, memory leaks, hot-path bloat |
| `types` | has typed files | Type design, invariant quality, encapsulation |
| `tests` | has test files | Test coverage gaps, behavioral vs implementation testing |
| `api` | has routes/endpoints | Breaking changes, missing deprecation, version bump needs |
| `frontend` | has frontend files | UI patterns, rendering efficiency, WCAG 2.1 accessibility |
| `web3` | has .sol or web3 imports | Solidity security, Anchor/Solana patterns, gas optimization |

### Language-specific (auto-detected)
| Agent | Language |
|-------|----------|
| `python` | Python — idioms, async pitfalls, type hints |
| `typescript` | TypeScript — type safety, generics, strict mode |
| `javascript` | JavaScript — async patterns, event loop, module issues |
| `go` | Go — error handling, goroutine leaks, channel misuse |
| `rust` | Rust — ownership, unsafe, lifetimes, error handling |
| `java` | Java — modern patterns, null safety, Spring Boot |
| `csharp` | C# — async/await, disposal, LINQ, EF Core |
| `kotlin` | Kotlin — null safety, coroutines, scope functions |
| `swift` | Swift — optionals, ARC, Sendable, SwiftUI |

## How it works

All 21 review agents are bundled as markdown files inside the orchestrator (`skills/pr-swarm/agents/*.md`). The orchestrator reads each agent's prompt, appends the PR context, and launches it as a background subagent scoped to the diff. No external dependencies — everything is a markdown file.

Each agent writes findings to `docs/reviews/PR-{N}/{agent-name}.md`. If your session crashes, the orchestrator detects existing state on next run and offers to resume.

After all agents return, findings are de-duplicated (multiple agents flagging the same file:line), categorized, and posted as a single PR comment.

## Supported languages

Python, TypeScript, JavaScript, Go, Rust, Java, C#, Kotlin, Swift, Solidity — plus language-agnostic agents for security, code quality, error handling, DRY analysis, performance, API design, frontend/accessibility, testing, type design, and documentation.

## License

MIT. See [ATTRIBUTION.md](ATTRIBUTION.md) for credits to upstream projects.
