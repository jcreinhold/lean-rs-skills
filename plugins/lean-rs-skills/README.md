# lean-rs-skills

A Codex and Claude Code plugin bundling a set of generic **Rust + Lean 4 craft skills** — the kind of reusable, project-independent guidance you want available in every systems / formal-methods project instead of copy-pasting skills between repos.

Each skill is self-contained under `skills/<name>/`: a lean `SKILL.md` plus `references/` for depth. Two skills (`deep-module-design`, `technical-writing`) also bundle helper agents under `skills/<name>/agents/` that the skill invokes by relative path for systematic reviews.

## Skills

| Skill | What it's for | Bundled agents |
| --- | --- | --- |
| **deep-module-design** | Designing Rust/Lean modules, crates, namespaces, or APIs: public/private boundaries, refactoring surface area, facade crates, information hiding, single-implementor traits. | `pre-design-audit`, `post-design-verify` |
| **optimizing-rust-performance** | Measurement-driven Rust performance work: throughput, allocations, memory footprint, cache locality, hot-path cloning, layout, hashing, pipeline latency, profiling, benches, regressions. | — |
| **optimizing-lean-performance** | Lean 4 performance: slow elaboration, heartbeat limits, typeclass loops, simp timeouts, large oleans, slow Lake builds, term bloat, module parallelism. | — |
| **technical-writing** | Writing, revising, or reviewing prose: docstrings, comments, mathematical exposition, issues, design docs, PR summaries, READMEs, commit messages. | `edit` |
| **test-engineering** | Rust tests: regressions, property tests, integration, compile-fail, benchmarks; minimal repros, law-based tests, brittle/slow/shallow suites, wrong-layer scope. | — |
| **writing-rust-macros** | Rust macros — declarative (`macro_rules!`) and procedural (derive, attribute, function-like): boilerplate reduction, trait impls, DSLs, repetition not solvable with generics or functions. | — |

Skills trigger automatically when your request matches their description; you don't invoke them explicitly.

## Installation

This repo uses the same basic distribution pattern as multi-host skill plugins such as Superpowers: one canonical skill tree plus small host-specific metadata surfaces. The skills live once, at `skills/`; host manifests and marketplace files describe how each agent should discover that same content.

### Repository layout

- Canonical plugin contents: `skills/`, `README.md`, `LICENSE`, and the root host manifests.
- Claude Code distribution: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` describe the repo root as the plugin.
- Codex distribution: `.agents/plugins/marketplace.json` describes a Codex marketplace whose plugin source is `./plugins/lean-rs-skills`.
- Codex adapter package: `plugins/lean-rs-skills/` is a generated package containing the Codex manifest, skills, README, and license.

The Codex adapter is intentional. Codex local marketplace discovery expects marketplace entries to point at a plugin package path such as `./plugins/<name>`; in practice, a marketplace entry whose plugin source is the marketplace root itself is not surfaced reliably. The adapter keeps Codex on that conventional path without making `plugins/lean-rs-skills/` the authoring location.

### Codex

Codex reads `.agents/plugins/marketplace.json`, whose `source.path` points at `./plugins/lean-rs-skills`. Install or refresh from that marketplace:

```bash
codex plugin marketplace add ~/Code/lean-rs-skills
codex plugin add lean-rs-skills@lean-rs-skills
```

For local development, validate both Codex plugin views from the repo root:

```bash
scripts/sync-codex-adapter.sh
uv run --with pyyaml /Users/jcreinhold/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .
uv run --with pyyaml /Users/jcreinhold/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/lean-rs-skills
```

After publishing marketplace changes, refresh and reinstall it in Codex:

```bash
codex plugin marketplace upgrade lean-rs-skills
codex plugin add lean-rs-skills@lean-rs-skills
```

### Claude Code

Claude Code reads `.claude-plugin/marketplace.json`, whose `source` points at `./`, so `claude --plugin-dir ~/Code/lean-rs-skills` and Claude marketplace installs use the root plugin directly.

### Claude Code marketplace

```
/plugin marketplace add jcreinhold/lean-rs-skills
/plugin install lean-rs-skills@lean-rs-skills
```

### Claude Code local testing

```
claude --plugin-dir ~/Code/lean-rs-skills
```

Then run `/help` to confirm the skills are listed.

## Design rationale

The repo keeps one canonical `skills/` tree for authoring. Claude Code can load that tree from the repo root. Codex loads a generated adapter package under `plugins/lean-rs-skills/`, matching Codex marketplace package layout. Regenerate the adapter with `scripts/sync-codex-adapter.sh` before validating or publishing Codex changes.

## Scope notes

- `optimizing-rust-performance`, `test-engineering`, and `writing-rust-macros` are intentionally Rust-focused. `optimizing-lean-performance` is Lean 4 specific.
- `deep-module-design` and `technical-writing` are language-agnostic.

## Provenance

These skills were consolidated from the canonical copies maintained across several Rust/Lean projects, then genericized (project-specific names removed) to serve as a single shared source of truth.

## License

MIT — see [LICENSE](LICENSE).
