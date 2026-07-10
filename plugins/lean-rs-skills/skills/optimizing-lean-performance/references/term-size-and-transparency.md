# Term Size and Transparency

How to control proof-term size, kernel type-checking time, and olean bloat.

Read this when the profiler blames `type checking`. That phase is the **kernel** re-checking the proof terms your tactics built. It is the phase people forget, it is invisible in the source, and no amount of tactic tuning touches it. The only lever is a smaller proof term.

## Table of Contents

1. [The Kernel Ignores Your Attributes](#the-kernel-ignores-your-attributes)
2. [What Makes a Proof Term Big](#what-makes-a-proof-term-big)
3. [`let` in Tactic Proofs](#let-in-tactic-proofs)
4. [Shrinking the Term](#shrinking-the-term)
5. [Transparency Hierarchy](#transparency-hierarchy)
6. [`noncomputable`](#noncomputable)
7. [Reduction Control Options](#reduction-control-options)
8. [Olean Size](#olean-size)

---

## The Kernel Ignores Your Attributes

`abbrev`, `@[reducible]`, and `@[irreducible]` tell the **elaborator** when it may unfold a definition. The kernel has no notion of reducibility. It unfolds whatever it needs to check the term in front of it.

So when `type checking` dominates:

- Marking the definition `@[irreducible]` will not help.
- Raising `maxHeartbeats` will not help; it will only let the kernel grind longer.
- Squeezing `simp` will not help, unless doing so makes the *term* smaller.

Only two things reduce kernel time: a smaller proof term, or a term that does not need deep reduction to check. Proof irrelevance gives you the second for free on `Prop`s — the kernel never unfolds a `theorem` body to compare it with another proof. It still has to *check* that body once.

`opaque` is the one declaration the kernel will not unfold, because it has no body.

## What Makes a Proof Term Big

| Source | Term size | Why |
| --- | --- | --- |
| `decide` on a nontrivial input | Very large | The kernel evaluates every step |
| `convert e using n` over dependent types | Large | Congruence and `HEq` obligations over big types |
| `simp` with many rewrites | Large | A chain of `Eq.mpr` and `congrArg` steps |
| `simpa [proj] using e` on a big structure | Large | Two `simp` runs plus a defeq check |
| tactic `let` bindings | Large | Each is zeta-expanded into the term |
| `aesop` | Large | The search tree is encoded in the term |
| `omega` | Small | Abstracts its proof into an auxiliary definition |
| `exact` / `apply` | Minimal | A direct reference |

`omega`'s abstraction is worth dwelling on: switching to it shrank one stdlib olean from 20 MB to 5 MB, because the parent theorem references an auxiliary definition by name instead of inlining the arithmetic proof.

## `let` in Tactic Proofs

A `let` inside a tactic proof is not free. It becomes part of the proof term, and if a later `simp` or `convert` is given the `let`-bound name, it unfolds that binding back into the goal:

```lean
theorem slow ... := by
  let core := bigConstruction h
  let Q := core.pairing
  let R := Q.op
  let e := someIso n m
  have h1 : ... := by simpa [core, Q, R, e] using hzero   -- unfolds all four
  convert h1 using 2 <;> first | rfl | exact HEq.rfl | ...
  ...
```

Each `simp [core, Q, R, e]` expands those definitions into the goal, `convert` builds congruence proofs over the expanded dependent types, and the kernel then checks the whole thing. The source looks tidy; the term does not.

A measured case. One 245-line file took 19.9 seconds; with `-Ddebug.skipKernelTC=true` it took 1.8. Bisecting the file put 17.7 of those seconds inside a single 40-line theorem shaped like the one above. Deleting its `convert` saved 0.2s. Deleting its `simpa` saved 0.3s. The tactics were not the cost. The `let` chain and the `have`s stacked on top of it were: each `have` type mentioned the `let`s, so each re-embedded their expansions, and the kernel checked all of it.

Two fixes, in order:

1. **Hoist the construction into a named `def`** outside the theorem, and prove the facts you need about it as named lemmas. The proof term then holds references, not bodies.
2. **Use `have` instead of `let`** when you only need the fact, not the definitional body. `have` is opaque; `let` is transparent, so `let` invites later reduction.

`let` is not banned. A `let` bound to a small term is free. The trap is a `let` bound to a heavy construction whose type then appears in later goals.

## Shrinking the Term

### Factor into named lemmas

Every `theorem` gets its own proof term and its own heartbeat budget. The parent references it by name, and by proof irrelevance the kernel never looks inside it again.

```lean
-- Before: one term holding three proofs.
theorem big : P ∧ Q ∧ R := by
  constructor
  · <100 lines>
  constructor
  · <100 lines>
  · <100 lines>

-- After: the parent's term is three name references.
private theorem big_p : P := by ...
private theorem big_q : Q := by ...
private theorem big_r : R := by ...
theorem big : P ∧ Q ∧ R := ⟨big_p, big_q, big_r⟩
```

This is the single most reliable way to cut kernel time. It is also the one that survives refactoring.

### Replace `convert` with `rw` then `exact`

`convert … using n` over dependent types is a term-size problem wearing a tactic's clothes. Rewrite the goal into shape, then close it exactly. See `tactic-performance.md`.

### Use `omega` for arithmetic

It abstracts. `simp` and `decide` inline.

### Squeeze search tactics

`simp?` and `aesop?` print what they did. Committing the explicit result skips the search and usually yields a smaller term.

### Do not reach for `native_decide`

It replaces the kernel's evaluation with the compiler's, so the term becomes a single opaque call — and the compiler joins your trusted base. Mathlib bans it: with it, "it is probably possible to prove `False`." Make the computation smaller instead.

## Transparency Hierarchy

This table governs the **elaborator**, not the kernel. It controls when `simp`, typeclass search, and `isDefEq` unfold a definition — which is where elaboration time goes, and where `definitions-and-instances.md` picks up the story.

| Keyword / attribute | Transparency | Unfolded by | Use for |
| --- | --- | --- | --- |
| `abbrev` | Reducible | `simp`, typeclass search, unifier | True synonyms, notation |
| `def` | Semireducible | Explicit `unfold` / `delta` | General definitions |
| `@[irreducible] def` | Irreducible | Nothing in the elaborator | Expensive internals |
| `opaque` | Opaque | Nothing, ever — including the kernel | FFI stubs, axiom-like |
| `theorem` | Proof-irrelevant | Nothing | All proofs |

### When to use `@[irreducible]`

Mark a definition `@[irreducible]` when downstream code should reason through lemmas rather than unfold, or when the definition is an implementation detail that keeps leaking into `simp` and typeclass search. Mathlib's stated reason: "so that Lean doesn't unfold it when trying to unify two different things."

`seal foo` applies it after the fact; `unseal foo in` lets one declaration see through.

Definitions by well-founded recursion have been `@[irreducible]` by default since Lean 4.9, because unfolding one forces the kernel to reduce its termination proof. Leave that alone.

Under the module system, sealing by visibility is cheaper still: an unexposed `def` body cannot be unfolded downstream at all. See `definitions-and-instances.md`.

## `noncomputable`

Marking a definition `noncomputable` skips the whole compiler pipeline — code generation, optimization, C emission. For a definition that exists only to be reasoned about, this is free speed. Mathlib does it explicitly for that reason: `noncomputable … -- just for performance; compilation takes several seconds`.

## Reduction Control Options

```lean
-- Use auxiliary match definitions for structural recursion (default: true).
-- Disabling forces full reduction of recursive definitions.
set_option smartUnfolding true

-- Lazy delta reduction in isDefEq (defaults: true).
set_option backward.isDefEq.lazyWhnfCore true
set_option backward.isDefEq.lazyProjDelta true
```

These defaults are almost always right. Change them only when a profile names the unification bottleneck.

Two options exist that trade soundness for speed. Neither belongs in committed code:

- `set_option debug.skipKernelTC true` — skips kernel type checking. A buggy tactic can now produce an unsound proof and nothing will catch it. Useful for a moment, to confirm the kernel really is the bottleneck.
- `set_option maxHeartbeats 0` — removes the timeout instead of the cause.

## Olean Size

```bash
# Largest oleans in the build
find .lake/build -name "*.olean" -exec ls -lS {} + | head -20
```

Lean stores proof terms in `.olean` files. Large terms mean slower `lake build`, slower language server startup, and more memory per import. An olean over about 1 MB for a module with few definitions points at `decide` on a big input, an unabstracted `simp` chain, or a proof that should have been three lemmas.

Proof irrelevance means the kernel never unfolds those terms downstream — but they are still serialized, shipped, and loaded.
