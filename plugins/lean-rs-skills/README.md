# lean-rs-skills

A Codex and Claude Code plugin with generic Rust and Lean 4 craft skills.

## Skills

| Skill | Use | Agent |
| --- | --- | --- |
| `module-design` | Rust/Lean module boundaries and APIs | `pre-design-audit`, `post-design-verify` |
| `proof-design` | Lean theorem statements and lemma structure | — |
| `rust-performance` | Measured Rust performance work | — |
| `lean-performance` | Lean elaboration, proof, and build cost | — |
| `rust-testing` | Rust test design and regressions | — |
| `rust-macros` | Declarative and procedural Rust macros | — |

Skills trigger from their descriptions.

## Layout

`skills/` is the canonical source. `plugins/lean-rs-skills/` is the generated Codex adapter; do not edit it.

- Claude Code loads the repository root through `.claude-plugin/`.
- Codex loads the adapter through `.agents/plugins/marketplace.json`.

Regenerate and validate both views from the repository root:

```bash
scripts/sync-codex-adapter.sh
uv run --with pyyaml /Users/jcreinhold/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .
uv run --with pyyaml /Users/jcreinhold/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/lean-rs-skills
```

## Install

```bash
codex plugin marketplace add ~/Code/lean-rs-skills
codex plugin add lean-rs-skills@lean-rs-skills
```

For Claude Code, use:

```bash
claude --plugin-dir ~/Code/lean-rs-skills
```

## License

MIT — see [LICENSE](LICENSE).
