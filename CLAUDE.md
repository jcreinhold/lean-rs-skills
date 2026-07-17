# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`lean-rs-skills` is a **dual Codex / Claude Code plugin**, not an application. It bundles reusable, project-independent **Rust + Lean 4 craft skills** so they don't have to be copy-pasted between projects. The "code" is almost entirely Markdown (`SKILL.md` + `references/`), with a few Bash audit scripts and per-skill agent definitions.

There is no compiler, test runner, or package manager here. The skills *describe* Rust/Lean workflows; they don't execute them.

## Validation: the only "build"

Markdown is checked and formatted with [`mdwright`](https://github.com/jcreinhold/mdwright) (already on PATH at `~/.cargo/bin/mdwright`). The repo dogfoods it via `.mdwright.toml` (wrap = 120, `CLAUDE.md` is excluded from both `fmt` and `lint`).

```bash
mdwright fmt      # format all Markdown (the commit "run mdwright formatter" does exactly this)
mdwright check    # lint without rewriting
```

Run `mdwright fmt` before committing any `.md` change. Bash scripts use `set -euo pipefail`; keep that. Validate the Codex plugin manifest with:

```bash
uv run --with pyyaml /Users/jcreinhold/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .
```

To exercise the plugin itself:

```bash
claude --plugin-dir ~/Code/lean-rs-skills   # load locally, then /help to confirm skills are listed
```

For Codex plugin validation, check both the root view and the Codex marketplace adapter:

```bash
scripts/sync-codex-adapter.sh
uv run --with pyyaml /Users/jcreinhold/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .
uv run --with pyyaml /Users/jcreinhold/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/lean-rs-skills
```

## Skill anatomy

Every skill lives under `skills/<name>/` and follows the same layout:

- `SKILL.md` — required. YAML frontmatter (`name`, `description`) + the lean, always-loaded body. The `description` is what triggers the skill, so it must enumerate the concrete situations the skill covers (see existing ones for the pattern: a short purpose clause followed by a comma-separated list of trigger phrases).
- `references/*.md` — depth loaded on demand. The `SKILL.md` body stays short and links into these for full theory or language-specific patterns. Keep the cognitive load on the body low; push detail down here.
- `agents/openai.yaml` — every skill has one. Declares `interface.display_name`, `short_description`, and a `default_prompt` that references the skill as `$skill-name`.
- `agents/*.md` — optional dispatchable sub-agents (currently `deep-module-design` only). The `SKILL.md` invokes them by relative path.
- `scripts/*.sh` — optional audit/helper scripts (only `deep-module-design` and `test-engineering` have these).
- `evals/evals.json` — eval suite (every skill has one): `{skill_name, evals: [{id, prompt, expected_output, files}]}`.

### Referencing bundled files from a SKILL.md

Scripts should be addressed relative to the plugin root so they work for both Codex and Claude Code:

```
bash skills/<name>/scripts/<script>.sh <path>
```

Claude Code also provides `${CLAUDE_PLUGIN_ROOT}` for commands that are run outside the plugin root, but skill prose should not require that variable. Use plain relative paths (e.g. `agents/pre-design-audit.md`, `references/rust-patterns.md`) when the body points the reader at a sibling file.

## Registration

Adding a skill requires no skill-list manifest edit — both hosts discover skills from `skills/`. Host-specific plugin metadata lives in separate manifests and rarely changes:

- `.claude-plugin/plugin.json` — plugin metadata (name, version, description, keywords).
- `.claude-plugin/marketplace.json` — marketplace entry pointing `source` at `./`.
- `.codex-plugin/plugin.json` — Codex metadata, interface presentation, and `skills: "./skills/"`.
- `.agents/plugins/marketplace.json` — Codex marketplace metadata pointing at `./plugins/lean-rs-skills`.
- `plugins/lean-rs-skills/` — generated Codex marketplace adapter package. Regenerate it with `scripts/sync-codex-adapter.sh`; do not edit generated adapter files directly.

### Why the Codex adapter exists

Claude Code can install the repo root directly through `.claude-plugin/marketplace.json`. Codex local marketplace discovery expects marketplace entries to point at a package path like `./plugins/<name>`, and a root-as-plugin source is not surfaced reliably. The adapter keeps Codex on that expected layout while preserving root `skills/` as the authoring source.

Keep the skill table in `README.md` in sync when you add, remove, or rescope a skill.

## Core constraint: skills must stay generic

These skills were consolidated from canonical copies across several Rust/Lean projects and **genericized** — all project-specific crate names, type names, and paths were stripped so this repo is a single shared source of truth. Preserve that:

- No references to a specific downstream project's crates, modules, or directory structure.
- Examples should be illustrative and language-idiomatic, not lifted from one private codebase.
- Bash audit scripts dispatch by language/layout detection (file extension, `Cargo.toml`, `lakefile.*`), not by hard-coded project paths.

## Style of the skill prose

The existing skills share a deliberate shape worth matching when editing or adding one:

- An **"Orient First"** table mapping design *pressures* to what to look for.
- A pointer to an **audit script** when the pressure is unclear.
- **Numbered core principles**, ordered by importance with an explicit "higher one wins" tiebreak.
- A **"Failure Smells"** table: smell → what it means → fix direction.
- A **"Before Declaring Done" / "Validation"** checklist with the concrete commands to run.
- For agent-facing skills, a **"Defaults to Resist"** section naming LLM failure modes (reflexive abstraction, stop-when-it-compiles, etc.) — these target Claude's own biases, not a human's.

When two skills overlap, they cross-link via a **"Related Skills"** section rather than duplicating content (e.g. `test-engineering` hands timing concerns off to `optimizing-rust-performance`).
