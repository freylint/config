# Claude instructions

Before writing code or planning an implementation, aggressively apply widely accepted best practices for the language and ecosystem in use — prefer idiomatic patterns, established conventions, and proven solutions over novel ones.


After every code change, aggressively refactor the affected file(s):
- Minimise lines of code without sacrificing clarity
- Eliminate redundancy (repeated strings, verbose inherit blocks, unnecessary blank lines)
- Prefer idiomatic Nix patterns (`inherit`, `@attrs`, `let` bindings for repeated values, single-line lists when short)
- Do not stop refactoring until no further line reductions are possible
- Preserve the hexagonal module architecture — keep concerns in separate files

## File header comments

Every file must have a header comment listing its features/responsibilities. Keep it current:
- **New feature added** → add a line to the header of the file it lives in
- **Feature removed** → remove that line from the header
- Format: a brief, one-line bullet per feature; no prose

## Multi-agent review on every feature

### Steering quorum (runs first)

Before the refactoring quorum, spawn four agents to assess the change and produce a written directive. Each reads the diff and affected files, then states its position. Together they output a single steering brief — risks to watch, scope to cover, tradeoffs to resolve — that is passed verbatim to the refactoring quorum below.

- **CTO** — strategic coherence: does this fit the architecture vision, introduce unwanted coupling, or drift from the long-term direction? Flags decisions that look fine locally but create problems at scale
- **HR Director** — team and process standards: are conventions followed consistently, is the change reviewable and maintainable by someone who wasn't in this session, does it leave the codebase in a state a new contributor could navigate?
- **Technical Lead** — day-to-day correctness: owns the implementation details, checks for edge cases, integration risk, and whether the approach matches how the rest of the codebase actually works
- **Grizzled Veteran** — hard-won instinct: "we tried that and it burned us" — surfaces hidden risk, fragile assumptions, and patterns that look clever but rot in production

After all four state their position, synthesise into a steering brief (≤10 bullets) and hand it to the refactoring quorum.

### Refactoring quorum (runs after steering brief is ready)

Spawn a quorum of agents with clashing personalities to review and refactor the **entire affected codebase** — not just the new files. Each agent must:

1. Read every file in its assigned scope
2. Read the steering brief from the quorum above
3. Apply the refactoring and header rules above
4. State its argument: what it changed and why, and where it disagreed with a conservative reading

Suggested personalities (adapt names, keep the tension):
- **Brutus** — aggressive minimizer: cuts every line that can go, collapses inline, no mercy for verbose nesting
- **Scholar** — thorough documentarian: headers must be complete, every feature captured, justified WHY comments preserved
- **Craftsman** — idiomatic purist: `inherit`, `let` bindings, language-correct patterns above all
- **Rusher** — velocity maximizer: ships the simplest thing that works, argues against any change that adds friction without immediate payoff, calls out over-engineering and analysis paralysis
- **Warden** — style consistency enforcer: hunts naming inconsistencies, formatting divergence, and convention drift across files; flags anything that would look out of place if written by a different author

Assign non-overlapping file sets so agents can run in parallel. After all three complete, do a synthesis pass yourself: reconcile any contradictions, fix any file they missed, and run a build check to confirm nothing broke.

## run.py

Keep `run.py` in sync after any structural change:
- **New host** in `flake.nix` → add an entry to `HOSTS` with `host` and `user`
- **Removed host** → remove from `HOSTS`
- **New deploy target or pipeline step** → add a `Target` to `TARGETS` and a matching `case` in `run_target()`
- **Changed deploy pipeline** (e.g. different colmena flags) → update `_pipeline()` or the relevant helper
