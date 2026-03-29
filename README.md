# pr-review-swarm

Parallel PR review for Claude Code — one command launches up to 23 specialized agents, compiles a de-duplicated report, fixes findings, and grades the fix quality.

## Why this exists

Claude Code's built-in review agents are good individually, but there's no orchestration. You launch one at a time, read scattered outputs, fix manually, and if your session crashes mid-review you start over.

pr-review-swarm fixes this:

- **Parallel agent swarm** — auto-detects what's in the PR (languages, file types, patterns) and launches only the relevant agents simultaneously
- **Crash-resilient state** — each agent writes its own findings file to `docs/reviews/PR-{N}/`. If your session dies, resume where you left off
- **Compiled report** — de-duplicates findings across agents, categorizes as Must Fix / Suggestions / Nitpicks, posts as a PR comment
- **Automated fix pass** — sequentially fixes findings with atomic commits, runs tests, reverts breaking changes
- **Grading system** — `/pr-swarm-grade` cross-references the compiled report against actual diff, produces a letter-grade report card with dishonesty detection

## Install

Requires [Claude Code](https://claude.ai/code) and [GitHub CLI](https://cli.github.com) (`gh`).

```bash
git clone https://github.com/knkenko/pr-review-swarm.git /tmp/pr-review-swarm && \
  /tmp/pr-review-swarm/install.sh
```

This copies all skills to `~/.claude/skills/pr-swarm-*/`. To update, run the same command again.

### Manual install

Copy the `skills/` directories into `~/.claude/skills/`:

```bash
cp -r skills/pr-swarm* ~/.claude/skills/
```

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

### Grade a fix pass

After `/pr-swarm` fixes findings:

```
/pr-swarm-grade
```

Produces a letter-grade report card (A+ through F) by cross-referencing the compiled report against the actual diff. Catches dishonest claims, undocumented skips, and regressions.

### Run a single agent

Every agent is a standalone skill. Use any individually:

```
/pr-swarm-security
/pr-swarm-python
/pr-swarm-api
```

## Agents

### Always run
| Agent | What it checks |
|-------|---------------|
| `pr-swarm-code` | Code quality, bug detection, project convention compliance |
| `pr-swarm-security` | OWASP Top 10, secrets, dependency risks, infrastructure misconfigs, supply chain |

### Conditional (based on PR content)
| Agent | Runs when | What it checks |
|-------|-----------|---------------|
| `pr-swarm-errors` | has code | Silent failures, inadequate catch blocks, hidden error paths |
| `pr-swarm-simplify` | has code | Unnecessary complexity, redundant state, parameter sprawl, copy-paste |
| `pr-swarm-dry` | has code | Cross-file duplication, missed utility reuse |
| `pr-swarm-docs` | has code or docs-only | Comment accuracy, stale project documentation |
| `pr-swarm-efficiency` | has code | N+1 queries, concurrency bugs, memory leaks, hot-path bloat |
| `pr-swarm-types` | has .ts/.tsx/.py | Type design, invariant quality, encapsulation |
| `pr-swarm-tests` | has test files | Test coverage gaps, behavioral vs implementation testing |
| `pr-swarm-api` | has routes/endpoints | Breaking changes, missing deprecation, version bump needs |
| `pr-swarm-frontend` | has .tsx/.jsx/.vue/.svelte/.css | UI patterns, rendering efficiency, WCAG 2.1 accessibility |
| `pr-swarm-web3` | has .sol or web3 imports | Solidity security, Anchor/Solana patterns, gas optimization |

### Language-specific (auto-detected)
| Agent | Language |
|-------|----------|
| `pr-swarm-python` | Python — idioms, async pitfalls, type hints |
| `pr-swarm-typescript` | TypeScript — type safety, generics, strict mode |
| `pr-swarm-javascript` | JavaScript — async patterns, event loop, module issues |
| `pr-swarm-go` | Go — error handling, goroutine leaks, channel misuse |
| `pr-swarm-rust` | Rust — ownership, unsafe, lifetimes, error handling |
| `pr-swarm-java` | Java — modern patterns, null safety, Spring Boot |
| `pr-swarm-csharp` | C# — async/await, disposal, LINQ, EF Core |
| `pr-swarm-kotlin` | Kotlin — null safety, coroutines, scope functions |
| `pr-swarm-swift` | Swift — optionals, ARC, Sendable, SwiftUI |

## How it works

The orchestrator (`pr-swarm`) reads each agent's skill file from `~/.claude/skills/`, extracts the prompt, and launches it as a background agent scoped to the PR diff. No plugin dependencies — everything is a markdown file on disk.

Each agent writes findings to `docs/reviews/PR-{N}/{agent-name}.md`. If your session crashes, the orchestrator detects existing state on next run and offers to resume.

After all agents return, findings are de-duplicated (multiple agents flagging the same file:line), categorized, and posted as a single PR comment.

## License

MIT. See [ATTRIBUTION.md](ATTRIBUTION.md) for credits to upstream projects.
