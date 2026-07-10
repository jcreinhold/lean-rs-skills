# Tactic Performance

How to pick cheap tactics and avoid the traps.

Before you read this, run the profiler. If the dominant phase is `type checking`, the kernel is the problem and no tactic change here will help — read `term-size-and-transparency.md`. If it is `typeclass inference`, read `definitions-and-instances.md`. This file is for when `elaboration`, `simp`, or `tactic execution` dominate.

## Table of Contents

1. [Tactic Cost Order](#tactic-cost-order)
2. [Simp Discipline](#simp-discipline)
3. [Controlling the Simp Set](#controlling-the-simp-set)
4. [`convert` on Dependent Types](#convert-on-dependent-types)
5. [`simpa` Pays Twice](#simpa-pays-twice)
6. [Expensive `rfl` and `decide`](#expensive-rfl-and-decide)
7. [Mutual-Inductive Proofs](#mutual-inductive-proofs)
8. [Other Slow Tactics](#other-slow-tactics)
9. [Exponential Blowup](#exponential-blowup)

---

## Tactic Cost Order

Prefer the cheapest tactic that closes the goal. This order reflects cost, not generality.

### Tier 1: direct construction (microseconds)

- `exact e` — supplies the term. No search.
- `apply f` — one unification against `f`'s conclusion.
- `constructor` — one lookup and one unification.
- `assumption` — a linear scan of the local context.

### Tier 2: decision procedures (milliseconds)

- `omega` — linear `Nat`/`Int` arithmetic. Fast, and it abstracts its proof into an auxiliary definition, so the proof term stays small.
- `norm_num` — numeric normalization. Exits early when it does not apply.
- `ring` — commutative ring identities. Fast; slows on very large expressions, so factor them.
- `decide` — evaluates a `Decidable` instance **in the kernel**. Fine for `2 + 2 = 4`. The cost grows with the computation, and it lands in the `type checking` phase where no tactic tuning reaches it.

### Tier 3: rewriting (milliseconds to seconds)

- `rw [lemma]` — one directed rewrite. Use it when you know the lemma.
- `dsimp only [...]` — definitional rewrites only; the proof is `rfl`.
- `simp only [...]` — a fixed lemma set. No database scan.

### Tier 4: search (seconds)

- `simp` — scans the whole simp database through discrimination trees.
- `aesop` — best-first proof search.
- `convert` — generates congruence subgoals. See below.

`native_decide` does not appear here. It compiles the goal and trusts the result, bypassing the kernel. Mathlib bans it: its linter notes that "it is probably possible to prove `False` using `native_decide`." Do not reach for it to make a slow `decide` fast; make the computation smaller instead.

## Simp Discipline

Bare `simp` is the most common avoidable cost in a proof.

1. **Squeeze it.** `simp?` prints the `simp only [...]` it actually used. Commit that. It skips the database scan, and it will not silently change behavior when Mathlib adds a lemma next month.

2. **`dsimp` before `simp`** when the goal has definitional equalities. `dsimp` handles the cheap rewrites, leaving `simp` a smaller goal.

3. **Keep lemma lists short.** Every lemma in `simp only [...]` is tried against every subterm.

4. **Never `simp` in a loop.** `repeat simp` and `iterate simp` compound the cost. Simplify once, then rewrite.

5. **Never pass a recursive function to `simp`.** `simp [myRecursiveFn]` unfolds one step, produces a goal `simp` cannot close, and you still pay for the failed match. Prove per-constructor `@[simp]` equations instead.

6. **Do not add `@[simp]` to fix one proof.** Each new simp lemma slows every bare `simp` in every downstream file. A simp lemma belongs to a normal form: its right side must always be simpler, not merely different.

7. **Watch for `simp` before `omega`.** A bare `simp` that normalizes one `Nat` subterm scanned thousands of lemmas to do it. Drop it, or name the lemma.

## Controlling the Simp Set

When a lemma in the default set is expensive or wrong for one proof, do not restructure the library — scope the change:

```lean
-- Remove an expensive lemma for one declaration.
attribute [-simp] eqToHom_op in
theorem my_theorem : ... := by simp

-- Give a broad lemma low priority so it is tried last.
@[simp low] theorem broad_rewrite : ... := ...

-- Give a cheap, always-right lemma high priority.
@[simp high] theorem canonical_form : ... := ...
```

Mathlib uses `attribute [-simp] … in` 23 times and `@[simp high]` 93 times. Both are ordinary tools, not hacks.

## `convert` on Dependent Types

`convert e using n` unifies the goal with `e`'s type and leaves the mismatches as subgoals. Over dependent types — `Fin (d + 1)`, `HEq`, indexed families — those subgoals are congruence and heterogeneous-equality obligations over large terms, and the `using` depth controls how many it generates.

This is expensive:

```lean
convert hzero using 2 <;> first | rfl | exact HEq.rfl | exact congrArg f h
```

Each generated subgoal runs several definitional-equality attempts through that `first` alternation. Prefer to rewrite the goal into shape first, then close it exactly:

```lean
rw [index_eq, dim_eq]
exact hzero
```

If you need `convert`, use the smallest `using` depth that works.

## `simpa` Pays Twice

`simpa [lemmas] using e` simplifies the goal, simplifies the type of `e`, and then checks the two agree. On a large structure — where `lemmas` are projections like `Cell.index` and `Cell.dim` — that is two full `simp` runs over a big type plus a definitional-equality check.

When the projections have equation lemmas, `rw` them and use `exact`.

## Expensive `rfl` and `decide`

`rfl` asks the **kernel** to normalize both sides. `decide` asks the kernel to evaluate a `Decidable` instance. Both land in the `type checking` phase. They get expensive when the terms involve:

- well-founded recursion (the kernel unfolds the termination proof),
- large nested structures,
- long computation chains.

Alternatives, in order of preference:

- `omega` for arithmetic equalities.
- `simp only [...]` to reach a common form, then `rfl` on small terms.
- Equation lemmas, so nothing has to reduce at all.
- `@[irreducible]` on the definition — but note this constrains the *elaborator*, not the kernel. The kernel unfolds what it must regardless. Only a smaller proof term shrinks kernel time.

## Mutual-Inductive Proofs

Mutual inductives create traps ordinary inductives do not.

**`cases` over `induction` when a case split is all you need.** `induction` on a member of a mutual family invokes a recursor that carries one motive per member, so Lean elaborates and instantiates all of them even when your goal names one type. `cases` splits on the constructors and nothing else. If the proof genuinely recurses, write it as a `mutual` block of theorems and let each call the others by name.

**Size the blocks.** Every member of a `mutual` block elaborates in one shared context. A block of 20 lemmas where 5 genuinely need each other makes the other 15 pay for nothing. Split it.

**Prove per-constructor equations.** See rule 5 under Simp Discipline; this is where it bites hardest.

## Other Slow Tactics

- `nontriviality` — a convenience wrapper. Use `rcases subsingleton_or_nontrivial α` instead.
- `field_simp` — expensive on complex fractions. Consider directed `rw`s.
- `fun_prop` and other Aesop-based tactics — replacing them with the explicit lemma is almost always possible and cuts time appreciably. Discharging the goal with `assumption` or `rfl` *before* invoking Aesop also helps.
- `aesop` — squeeze it with `aesop?` and commit the script.

## Exponential Blowup

Four causes, in rough order of frequency:

1. **Typeclass backtracking.** An instance matches the head, fails deep in unification, backtracks, and the next one fails the same way. Supply the instance. See `definitions-and-instances.md`.

2. **Simp looping.** Two lemmas rewrite back and forth. Orient them consistently, or drop one. `set_option linter.loopingSimpArgs true` detects the cycle by simplifying each candidate's right side; it is expensive, so enable it only while diagnosing.

3. **Unification over large terms.** `isDefEq` on terms with shared subexpressions explores exponentially many paths once sharing is lost. Keep `let` bindings to preserve it. The diagnostics counter `def_eq: heuristic for f a =?= f b` counts these.

4. **Recursive tactic combinators.** `repeat (simp; ring)` can run forever. Bound it with `iterate n`, or restructure.
