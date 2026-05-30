# lean-rs-skills

A Claude Code plugin bundling a set of generic **Rust + Lean 4 craft skills** — the kind of
reusable, project-independent guidance you want available in every systems / formal-methods
project instead of copy-pasting `.claude/skills/` between repos.

Each skill is self-contained under `skills/<name>/`: a lean `SKILL.md` plus `references/` for
depth. Two skills (`deep-module-design`, `technical-writing`) also bundle helper agents under
`skills/<name>/agents/` that the skill invokes by relative path for systematic reviews.

## Skills

| Skill | What it's for | Bundled agents |
|-------|---------------|----------------|
| **deep-module-design** | Designing Rust/Lean modules, crates, namespaces, or APIs: public/private boundaries, refactoring surface area, facade crates, information hiding, single-implementor traits. | `pre-design-audit`, `post-design-verify` |
| **optimizing-rust-performance** | Measurement-driven Rust performance work: throughput, allocations, memory footprint, cache locality, hot-path cloning, layout, hashing, pipeline latency, profiling, benches, regressions. | — |
| **optimizing-lean-performance** | Lean 4 performance: slow elaboration, heartbeat limits, typeclass loops, simp timeouts, large oleans, slow Lake builds, term bloat, module parallelism. | — |
| **technical-writing** | Writing, revising, or reviewing prose: docstrings, comments, mathematical exposition, issues, design docs, PR summaries, READMEs, commit messages. | `edit` |
| **test-engineering** | Rust tests: regressions, property tests, integration, compile-fail, benchmarks; minimal repros, law-based tests, brittle/slow/shallow suites, wrong-layer scope. | — |
| **writing-rust-macros** | Rust macros — declarative (`macro_rules!`) and procedural (derive, attribute, function-like): boilerplate reduction, trait impls, DSLs, repetition not solvable with generics or functions. | — |

Skills trigger automatically when your request matches their description; you don't invoke them
explicitly.

## Installation

### Via marketplace (recommended)

```
/plugin marketplace add jcreinhold/lean-rs-skills
/plugin install lean-rs-skills@lean-rs-skills
```

### Local testing

```
claude --plugin-dir ~/Code/lean-rs-skills
```

Then run `/help` to confirm the skills are listed.

## Scope notes

- `optimizing-rust-performance`, `test-engineering`, and `writing-rust-macros` are intentionally
  Rust-focused. `optimizing-lean-performance` is Lean 4 specific.
- `deep-module-design` and `technical-writing` are language-agnostic.

## Provenance

These skills were consolidated from the canonical copies maintained across several Rust/Lean
projects, then genericized (project-specific names removed) to serve as a single shared source of
truth.

## License

MIT — see [LICENSE](LICENSE).
