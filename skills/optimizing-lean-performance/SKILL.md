---
name: optimizing-lean-performance
description: 'Use for Lean 4 performance: slow elaboration, heartbeat timeouts, typeclass search, simp timeouts, repeated dsimp/unfold of a definition, reducible abbrev blowup, @[expose] and module-system unfolding, large oleans, slow Lake builds.'
---

# Optimizing Lean 4 Performance

Find and fix slow Lean 4 elaboration, proofs, and builds.

Your guess about why a Lean file is slow will usually be wrong, and in a specific way: you will blame a tactic you can see, when the cost sits in a phase you cannot. Measure first. Every time.

## Orient First

Match the pressure you feel to what to look for.

| Pressure | Look for | Read |
| --- | --- | --- |
| Anything, before you have profiled | Which **phase** burns the time, not which tactic looks scary | `references/profiling-and-diagnostics.md` |
| The profiler blames `type checking` | The kernel grinding on a big proof term | `references/term-size-and-transparency.md` |
| The profiler blames `typeclass inference` | Instances re-derived; non-canonical instance terms | `references/definitions-and-instances.md` |
| The profiler blames `elaboration` or `simp` | A tactic doing more work than you asked | `references/tactic-performance.md` |
| The same `dsimp [myDef]` in proof after proof | A definition with no equation lemmas | `references/definitions-and-instances.md` |
| The olean is huge | Proof terms inlined instead of named | `references/term-size-and-transparency.md` |
| `lake build` drags | Import surface and the critical path | `references/compilation-and-build.md` |

If the pressure is unclear, run the audit and let the counts point you:

```bash
bash skills/optimizing-lean-performance/scripts/audit-lean-perf.sh <path>
```

## Measure First

Four tools. They answer different questions, so pick by question.

| Tool | Answers |
| --- | --- |
| `set_option profiler true` | Where the seconds go: elaboration, typeclass search, or the kernel |
| `set_option diagnostics true` | What Lean keeps unfolding and searching |
| `set_option trace.profiler true` | Which tactic, as a tree with times |
| `#count_heartbeats in` | What this proof costs, as a number you can compare later |

Start with `profiler` and read the cumulative table before you touch anything. Here is one from a real 20-second file:

```
type checking took 18.1s
cumulative profiling times:
    dsimp                 25.5ms
    elaboration           35.3ms
    simp                  232ms
    tactic execution      357ms
    typeclass inference   74.5ms
    type checking         18.1s
```

Every tactic in that file, added up, costs under half a second. The **kernel** costs eighteen. Squeezing `simp` there would have bought back a hundredth of a percent. Rerunning with `-Ddebug.skipKernelTC=true` took 1.8 seconds, which settles it: the elaborator was never the problem.

`type checking` is the phase people forget, because nothing in the source names it. The kernel re-checks every proof term your tactics build, and it ignores `abbrev`, `@[reducible]`, and `@[irreducible]` — those bind the elaborator, not the kernel. The only fix is a smaller proof term.

Once you know the phase, use `diagnostics` to name the culprit. It reports **counters, not heartbeats**.

Each section names a distinct fix. This table is the fastest route from a symptom to a cause:

| Counter section | What it means | Fix direction |
| --- | --- | --- |
| `reduction: unfolded declarations` | Lean is peeling a `def` open, over and over | Seal it; prove equation lemmas |
| `reduction: unfolded reducible declarations` | An `abbrev` is being re-inlined | Make it a `def` |
| `reduction: unfolded instances` | An instance body is being unfolded to compare terms | `inferInstanceAs`, `fast_instance%` |
| `type_class: used instances` | The same instance is derived again and again | Register it once |
| `type_class: max synth pending failures` | Nested synthesis is blowing up | Raise `maxSynthPendingDepth`, or simplify the type |
| `def_eq: heuristic for f a =?= f b` | Unification is guessing on big terms | Supply explicit arguments |
| `kernel: unfolded declarations` | The kernel is reducing during the final check | Shrink the proof term |

`#count_heartbeats in` is a watermark, not a tuning knob. It suggests the smallest limit of the form `2^k * 200000` that works. Mathlib's own advice: **resist the temptation to set the limit as low as possible** — the library shifts under you, and a tight limit turns someone else's unrelated change into your build failure.

## Core Principles

Ordered. When two conflict, the higher one wins.

1. **Measure before you change.** The tactic that looks slow usually is not. Profile, name the phase, then act. A fix aimed at the wrong phase buys nothing, however sound the advice behind it.

2. **Watch the proof term, not just the tactic.** Tactics are how you write a term; the kernel pays for the term you wrote. A tidy fifty-line proof can build an enormous one. When `type checking` dominates, shrink the term.

3. **Pay a cost once, not once per site.** If a derivation appears in three proofs, give it a name — a lemma, an instance, a `def` — and each proof becomes a reference to that name.

4. **A definition is an interface.** Seal the body; publish lemmas. A definition whose body every downstream proof must unfold is not a definition, it is a macro, and you pay to expand it everywhere.

5. **Give the elaborator less to guess.** Explicit arguments, explicit instances, and canonical instance terms cost you keystrokes and save Lean an exponential search.

6. **Prefer the cheapest tactic that closes the goal.** `exact` over `apply` over `rw` over `simp only` over `simp`. Squeeze search tactics into their explicit results with `simp?` and `aesop?` before you commit.

7. **Shrink the import surface.** Every import adds instances to the search and lemmas to the `simp` database, in your file and in every file that imports yours.

## Failure Smells

| Smell | What it means | Fix |
| --- | --- | --- |
| `let x := <heavy term>` in a tactic proof, mentioned in later `have` types | Each `let` is expanded into the proof term, and every `have` above it re-embeds the expansion | Hoist to a top-level `def`; prove named lemmas about it |
| `convert e using 4` with `HEq` fallbacks | Congruence subgoals over dependent types, and a large term to check | `rw` into shape first, then `exact` |
| `simpa [proj] using e` on a large structure | Two `simp` runs over a big type plus a defeq check | Rewrite with equation lemmas; `exact` |
| A 40-line proof that dominates a whole file | Its term, not its tactics | Split it into named lemmas |
| `dsimp [myDef, myDefData]` in proof after proof | The definition has no equation lemmas | Prove them once; `rw` instead |
| `def foo : T := by …` where `T` is data | The body is `dite` under `Eq.mpr` motive scaffolding, which nothing reduces cheaply | Write the body in term mode |
| `abbrev foo := (bar x).1` | Reducible, so Lean re-inlines that term on every defeq check | Make it a `def` |
| `@[expose]` on a heavy `def` | Every downstream file may unfold the body | Drop it; export lemmas instead |
| `haveI : C x := by …` in two proofs | This is an `instance` | Register it once |
| `set_option maxHeartbeats` in a diff | The proof is not finished | Find the real cost |
| `simp` alone on a line, then `omega` | `simp` scanned the whole database to normalize one `Nat` | `simp only [...]`, or drop it |

## Defaults to Resist

Reaching for these feels like progress. It is not.

- **Blaming the scariest-looking tactic.** The `simp_all` you can see is rarely the `simp_all` that costs. Read the cumulative table, then bisect the file — truncate it after each declaration and time the prefixes. One theorem usually owns almost all of the time, and it is often not the one you expected.
- **Bumping the heartbeats.** Mathlib has no real `maxHeartbeats` bumps in its proof files, and two linters that reject them. A timeout is a diagnosis, not an obstacle.
- **`native_decide` to make it go away.** It trusts the whole compiler, not the kernel. Mathlib bans it outright: with it, "it is probably possible to prove `False`."
- **Reaching for `simp` where `rw` would do.** `simp` searches thousands of lemmas to apply the one you already knew.
- **Adding a global `instance` for a fact used once.** A true fact is not automatically a good instance. It joins every future search, including the ones where it fails deep and backtracks.
- **Adding `@[simp]` to fix one proof.** It slows every `simp` in every file downstream, forever.
- **Stopping when it compiles.** Compiling is the starting line. Re-measure.

## Before Declaring Done

- Re-measure with `#count_heartbeats in`. State the before and after; do not assert an improvement you did not observe.
- Remove every `set_option` you added to investigate. Committed `trace`, `profiler`, `pp`, and `debug` options are a smell, and Mathlib's `linter.style.setOption` rejects them.
- No new `maxHeartbeats` bump. If you truly need one, scope it with `in` and write a comment saying why.
- No `native_decide`, no `set_option maxHeartbeats 0`, no `debug.skipKernelTC` — each trades soundness for speed.
- `lake build` is clean.

## References

- `references/profiling-and-diagnostics.md` — the four tools, the counter-to-fix map, `#count_heartbeats` and `guard_min_heartbeats`, Firefox Profiler
- `references/definitions-and-instances.md` — sealing definitions, equation lemmas, `abbrev` and `@[expose]`, registering and shaping instances
- `references/tactic-performance.md` — tactic cost order, `simp` discipline, `convert` and `simpa`, exponential blowup
- `references/term-size-and-transparency.md` — proof-term size, olean bloat, transparency, `noncomputable`
- `references/compilation-and-build.md` — Lake parallelism, imports, module layout, incremental builds

## Related Skills

- **`deep-module-design`** — principle 3 is deep-module thinking applied to a definition: a narrow interface over a sealed body. When sealing a definition means redesigning its API, go there.
- **`optimizing-rust-performance`** — the same measure-first discipline for Rust.
