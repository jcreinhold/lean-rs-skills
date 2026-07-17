# Profiling and Diagnostics

How to find the bottleneck in slow Lean 4 code. Start here, every time.

Guessing does not work. The expensive step in a Lean file is often a definitional-equality check or a kernel reduction that appears nowhere in the source, while the tactic that *looks* frightening costs milliseconds. Measure.

## Table of Contents

1. [Which Tool Answers Which Question](#which-tool-answers-which-question)
2. [The Wall-Clock Profiler](#the-wall-clock-profiler)
3. [Reading the Phase Breakdown](#reading-the-phase-breakdown)
4. [Diagnostics: What Lean Keeps Unfolding](#diagnostics-what-lean-keeps-unfolding)
5. [The Counter-to-Fix Map](#the-counter-to-fix-map)
6. [Tactic-Level Trace Profiler](#tactic-level-trace-profiler)
7. [Firefox Profiler](#firefox-profiler)
8. [Counting Heartbeats](#counting-heartbeats)
9. [Minimizing a Slow Example](#minimizing-a-slow-example)
10. [Targeted Traces](#targeted-traces)
11. [Bisecting a File](#bisecting-a-file)
12. [Workflow](#workflow)

---

## Which Tool Answers Which Question

| Tool | Answers | Cost |
| --- | --- | --- |
| `set_option profiler true` | Where the seconds go, by phase | Cheap |
| `set_option diagnostics true` | What Lean unfolds and searches | Cheap |
| `set_option trace.profiler true` | Which tactic, as a timed tree | Verbose |
| `#count_heartbeats in` | What this proof costs, as a number | Cheap |

Run `profiler` first. It splits the time into elaboration, typeclass inference, and type checking — and those three send you to three different references. Everything else is follow-up.

## The Wall-Clock Profiler

```lean
set_option profiler true in
set_option profiler.threshold 250 in   -- ms; default 100
theorem slow : ... := by ...
```

Or over a whole file, which is usually what you want:

```bash
lake env lean -Dprofiler=true -Dprofiler.threshold=250 MyProject/Slow.lean
```

It prints per-command timings and then a cumulative table.

## Reading the Phase Breakdown

The cumulative table is the whole point. A real example from a 19-second file:

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

Read that carefully. The tactics cost 357ms. Typeclass inference costs 74ms. **The kernel costs 18.1 seconds.** Squeezing `simp` there would buy back a fraction of one percent.

Each phase points somewhere different:

| Dominant phase | Meaning | Read |
| --- | --- | --- |
| `elaboration` | Building the proof term is slow | `references/tactic-performance.md` |
| `typeclass inference` | Instance search is slow | `references/definitions-and-instances.md` |
| `type checking` | The **kernel** is re-checking your proof terms | `references/term-size-and-transparency.md` |
| `simp` / `tactic execution` | A specific tactic | `references/tactic-performance.md` |
| `import` | Import surface | `references/compilation-and-build.md` |

`type checking` is the phase people forget. The kernel re-checks every proof term you produce, and it honors no reducibility attribute: `@[irreducible]`, `abbrev`, and `@[reducible]` all mean nothing to it. It unfolds what it must. Big proof terms over big dependent types are expensive there and nowhere else, so no tactic-level fix touches them. The fix is to make the proof term smaller — see `term-size-and-transparency.md`.

### Confirming the kernel is the problem

`debug.skipKernelTC` turns off kernel type checking. Run the file with and without it:

```bash
lake env lean Slow.lean                            # 19.9s
lake env lean -Ddebug.skipKernelTC=true Slow.lean  #  1.8s
```

If the time collapses, everything the elaborator does is cheap and the proof term is the problem. That is a diagnosis, not a fix: with this option a buggy tactic can produce an unsound proof and nothing will catch it. Never commit it.

## Diagnostics: What Lean Keeps Unfolding

```lean
set_option diagnostics true in
set_option diagnostics.threshold 100 in   -- default 20
theorem slow : ... := by ...
```

**This does not report heartbeats.** It reports counters: how many times Lean unfolded each declaration, tried each instance, and fell back on a unification heuristic. Output looks like this:

```
[diag] Diagnostics
  [reduction] unfolded declarations (max: 5611, num: 50):
    [reduction] DFunLike.coe ↦ 5611
    [reduction] dite ↦ 396
  [reduction] unfolded reducible declarations (max: 1561, num: 20):
    [reduction] Subtype.val ↦ 1561
    [reduction] Decidable.casesOn ↦ 396
  [reduction] Axioms (possibly imported non-exposed defs) tried to be unfolded (max: 438, num: 1):
    [reduction] Classical.choice ↦ 438
```

A `dite` unfolded 396 times, next to `Decidable.casesOn` unfolded 396 times, is a definition whose body is a tactic-generated `if`. See `definitions-and-instances.md`.

## The Counter-to-Fix Map

Each section names a different disease. This is the fastest route from a counter to a cause:

| Counter section | What it means | Fix direction |
| --- | --- | --- |
| `reduction: unfolded declarations` | Lean peels a `def` open, repeatedly | Seal it; prove equation lemmas |
| `reduction: unfolded reducible declarations` | An `abbrev` is re-inlined on every defeq check | Make it a `def` |
| `reduction: unfolded instances` | An instance body is unfolded to compare terms | `inferInstanceAs`, `fast_instance%` |
| `reduction: Axioms … tried to be unfolded` | Lean is reducing through `Classical.choice` | The term hides a noncomputable choice; state a lemma about it |
| `type_class: used instances` | The same instance is derived again and again | Register it once |
| `type_class: max synth pending failures` | Nested synthesis is blowing up | Raise `maxSynthPendingDepth` (default 1), or simplify the type |
| `def_eq: heuristic for f a =?= f b` | Unification is guessing on big terms | Supply explicit arguments |
| `kernel: unfolded declarations` | The kernel is reducing during the final check | Shrink the proof term; stop using `rfl`/`decide` |

## Tactic-Level Trace Profiler

```lean
set_option trace.profiler true in
set_option trace.profiler.threshold 10 in   -- ms
theorem slow : ... := by ...
```

A timed tree in the Infoview, one node per tactic. Use it once `profiler` has told you the time really is in tactic execution — otherwise it will show you a tree that adds up to nothing.

## Firefox Profiler

For a flame graph, export the trace:

```bash
lake env lean -Dtrace.profiler=true \
  -Dtrace.profiler.output=profile.json \
  -Dtrace.profiler.output.pp=true \
  MyProject/Slow.lean
```

Then open `profile.json` at `profiler.firefox.com`.

`trace.profiler.output` **does not work as an in-file `set_option`.** It must be set before the interpreter starts, so pass it with `-D` as above.

Newer toolchains can skip the file: `-Dtrace.profiler.serve=true` serves the data over HTTP and opens the Firefox Profiler for you, blocking until you interrupt it.

## Counting Heartbeats

A heartbeat is about 1,000 small memory allocations. The default budget is 200,000 per command.

The commands live in Mathlib (`Mathlib.Util.CountHeartbeats`) and all take a leading `#`:

```lean
#count_heartbeats in
theorem my_theorem : ... := by ...        -- prints the count, suggests a limit

#count_heartbeats! 10 in
theorem my_theorem : ... := by ...        -- runs 10×; prints min, max, stddev
```

Use it as a **watermark**, not a tuning knob: record the number before you optimize and after, so the improvement you claim is one you observed.

`#count_heartbeats in` suggests the smallest limit of the form `2^k * 200000` that works. Mathlib's own guidance is to **resist the temptation to set the limit as low as possible**: the library moves under you, and a tight limit converts someone else's unrelated change into your build failure.

Related budgets:

| Option | Default |
| --- | --- |
| `maxHeartbeats` | 200000 (0 = no limit) |
| `synthInstance.maxHeartbeats` | 20000 |
| `synthInstance.maxSize` | 128 |
| `maxSynthPendingDepth` | 1 |
| `maxRecDepth` | 512 |

## Minimizing a Slow Example

When you cut a slow proof down to report or fix it, each cut risks deleting the slowness along with the code. `guard_min_heartbeats` fails the build if the declaration gets *faster* than a floor you set, so a cut that accidentally removes the problem stops you rather than fooling you:

```lean
guard_min_heartbeats 400000 in
theorem still_slow : ... := by ...
```

## Targeted Traces

Once you know the subsystem:

```lean
set_option trace.Meta.synthInstance true in       -- instances tried, in order
set_option trace.Meta.Tactic.simp.rewrite true in -- which simp lemmas fire
set_option trace.Meta.isDefEq true in             -- definitional equality checks
```

These are loud. Point them at one command, never a file.

## Bisecting a File

When the profiler blames a phase but not a line — the kernel's `type checking took 18.1s` carries no source position — bisect. Copy the file somewhere else (imports resolve from the built oleans, so it need not sit in the source tree), truncate it after each declaration, and time each prefix:

```bash
for cut in 40 80 120 160 200; do
  head -n $cut Slow.lean > /tmp/cut.lean
  /usr/bin/time -p lake env lean /tmp/cut.lean 2>&1 | awk '/^real/{print "'"$cut"'", $2}'
done
```

The jump between two prefixes is the cost of the declarations between them. This finds in a minute what reading finds in an hour.

## Workflow

1. `set_option profiler true`. Read the cumulative table. Identify the dominant phase.
2. If no line is named, bisect the file to find the declaration.
3. `set_option diagnostics true`. Read the counters. Use the counter-to-fix map above.
4. Fix the cause the counters name — not the tactic that looks slow.
5. Re-measure with `#count_heartbeats in` and `profiler`. State the before and after.
6. Delete every option you added. Committed `profiler`, `trace`, `pp`, and `debug` options are a smell; Mathlib's `linter.style.setOption` rejects them.
