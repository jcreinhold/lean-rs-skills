---
name: lean-performance
description: 'Use for Lean 4 performance: slow elaboration, heartbeat timeouts, typeclass search, simp timeouts, repeated dsimp/unfold of a definition, reducible abbrev blowup, @[expose] and module-system unfolding, large oleans, slow Lake builds.'
---

# Optimizing Lean 4 Performance

Measure first. The costly phase often differs from the tactic that looks slow.

## Orient First

| Symptom | Read |
| --- | --- |
| No profile yet | `references/profiling-and-diagnostics.md` |
| `type checking` dominates | `references/term-size-and-transparency.md` |
| Typeclass inference dominates | `references/definitions-and-instances.md` |
| Elaboration or `simp` dominates | `references/tactic-performance.md` |
| Repeated unfolding or `dsimp` | `references/definitions-and-instances.md` |
| Large oleans | `references/term-size-and-transparency.md` |
| Slow `lake build` | `references/compilation-and-build.md` |

If unsure, run:

```bash
bash skills/lean-performance/scripts/audit-lean-perf.sh <path>
```

## Measure

| Tool | Use |
| --- | --- |
| `set_option profiler true` | Find the costly phase. |
| `set_option diagnostics true` | Find repeated unfolding and search. |
| `set_option trace.profiler true` | Find costly tactics. |
| `#count_heartbeats in` | Compare a focused proof before and after. |

Profile before changing code. Diagnostics report counters, not heartbeats. Do not use `-Ddebug.skipKernelTC=true` except to separate kernel cost while investigating.

## Rules

1. Match the fix to the measured phase.
2. When the kernel dominates, shrink the proof term; tactic transparency settings do not change kernel checking.
3. Name work used at several sites as a lemma, instance, or `def`.
4. Seal definition bodies and publish equation lemmas rather than making callers unfold them.
5. Give elaboration explicit arguments and canonical instances when diagnostics show search or unification cost.
6. Prefer `exact`, `rw`, and bounded `simp only` to open-ended search when they suffice.
7. Keep imports narrow.

## Common Signs

| Sign | Fix |
| --- | --- |
| Large proof term or `type checking` cost | Split and name lemmas. |
| Repeated `dsimp [foo]` | Add equation lemmas and rewrite. |
| `abbrev` expands in defeq | Use `def`. |
| Heavy `@[expose]` body | Hide it; export lemmas. |
| Same local instance appears repeatedly | Register or name it once. |
| `convert` or broad `simpa` on large terms | Rewrite into shape, then use `exact`. |
| `simp` followed by a targeted tactic | Use the required rewrites or `simp only`. |

## Do Not

- Raise `maxHeartbeats` instead of finding the cost. If unavoidable, scope it with `in` and explain it; never set it to `0`.
- Commit trace, profiler, debug, or display options.
- Use `native_decide`, `set_option maxHeartbeats 0`, or `debug.skipKernelTC` as a fix.
- Add a global instance or `@[simp]` lemma for a one-off proof.

Mathlib rejects ordinary proof-file heartbeat bumps; treat a timeout as evidence to profile, not a limit to raise.

## Before Declaring Done

- Re-measure and report the workload, command, and before/after result.
- Remove investigation options.
- Keep any necessary heartbeat limit scoped with `in` and explain it.
- Run `lake build`.

## References

- `references/profiling-and-diagnostics.md` — tools and counters.
- `references/definitions-and-instances.md` — definitions and instances.
- `references/tactic-performance.md` — tactic costs.
- `references/term-size-and-transparency.md` — proof terms and transparency.
- `references/compilation-and-build.md` — imports and builds.

## Related Skills

- `module-design` when sealing a definition needs an API change.
- `rust-performance` for Rust measurement work.
