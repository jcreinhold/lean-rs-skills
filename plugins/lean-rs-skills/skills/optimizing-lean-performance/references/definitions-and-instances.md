# Definitions and Instances

How the shape of a definition sets the cost of every proof that mentions it, and how to shape instances so typeclass search stays cheap.

## Table of Contents

1. [The Governing Idea](#the-governing-idea)
2. [Write Data in Term Mode](#write-data-in-term-mode)
3. [Seal the Body, Publish the Equations](#seal-the-body-publish-the-equations)
4. [`abbrev` Is Reducible](#abbrev-is-reducible)
5. [The Module System Is a Performance Lever](#the-module-system-is-a-performance-lever)
6. [Register the Instance Once](#register-the-instance-once)
7. [Shaping Instance Terms](#shaping-instance-terms)
8. [Withholding Instances](#withholding-instances)
9. [`@[irreducible]`, `seal`, `unseal`](#irreducible-seal-unseal)
10. [Worked Example](#worked-example)

---

## The Governing Idea

A definition Lean can unfold is a definition Lean *will* unfold — during `simp`, during typeclass search, during every definitional-equality check the elaborator runs behind your back. You never see those checks in the source, which is why this cost is so easy to miss and so hard to guess at.

So the cost of a definition is not what it costs to elaborate once. It is:

```
cost of unfolding the body  ×  number of places Lean decides to unfold it
```

You control both factors. Shrink the first by writing a body that reduces cheaply. Shrink the second to near zero by sealing the body and giving proofs lemmas to use instead.

## Write Data in Term Mode

Tactics are for proofs. When you build **data** — a structure, a subtype, anything that is not a `Prop` — write the body as a term.

```lean
-- Slow. The body is a `dite` buried under `Eq.mpr` and motive lambdas that
-- `subst` and `have` left behind. No `dsimp` peels this cheaply.
def widget (k : Fin (n + 1)) (hk : 0 < k.1) : Widget n k := by
  by_cases hkn : k.1 < n
  · exact innerWidget hkn
  · have hlast : k = Fin.last n := by apply Fin.ext; simp; omega
    subst hlast
    exact edgeWidget hk

-- Fast. The body is a `dite` and nothing else. It has two obvious equations,
-- and you can state them.
def widget (k : Fin (n + 1)) (hk : 0 < k.1) : Widget n k :=
  if hkn : k.1 < n then innerWidget hkn else edgeWidget (lastOfNotLt hkn)
```

Tactic mode records *how you convinced Lean*, not *what you meant*. `subst`, `have`, and `rcases` each wrap the result in `Eq.mpr` applications carrying motive lambdas. Every later proof that wants to see through the definition has to reduce that scaffolding first.

Proofs escape this because of proof irrelevance: the kernel never unfolds a `theorem`. Data has no such protection.

A `def … := by` producing data is the loudest smell in this reference. Hoist the side conditions into named lemmas (`lastOfNotLt` above) and keep the body a term.

## Seal the Body, Publish the Equations

Once the body is a term, state its equations once and let every proof use them:

```lean
theorem widget_of_lt (hkn : k.1 < n) : widget k hk = innerWidget hkn := dif_pos hkn

theorem widget_of_not_lt (hkn : ¬ k.1 < n) : widget k hk = edgeWidget _ := dif_neg hkn
```

Now downstream proofs `rw [widget_of_lt hkn]` — one rewrite, no unfolding — instead of `dsimp [widget]; simp only [hkn, dif_pos]`, which peels the body open and then discharges the branch, at every site.

Tag them `@[simp]` only if they form a normal form: the right-hand side should always be simpler, not merely different.

The moment you catch yourself writing `dsimp [myDef]` or `unfold myDef` in a second proof, stop. The definition is missing a lemma. Write it.

## `abbrev` Is Reducible

`abbrev` means "reducible": `simp`, typeclass search, and the elaborator's unifier all unfold it freely, without asking.

Use it for true synonyms and notation, where the body is a name or a tiny application:

```lean
abbrev Nat.Positive := { n : Nat // 0 < n }   -- fine
```

Do not use it to give a short name to a heavy term:

```lean
abbrev widget (k : Fin (n + 1)) (hk : 0 < k.1) := (widgetData k hk).1   -- trap
```

That `abbrev` inlines `(widgetData k hk).1` — and thus all of `widgetData`'s body — into every type Lean compares. The diagnostics counter `reduction: unfolded reducible declarations` is exactly this happening. Make it a `def`.

The same reasoning applies to `@[reducible] def`. Mathlib uses far more `abbrev`s than `@[reducible]`s; when it wants reducibility it says `abbrev`, and it reserves both for genuinely small bodies.

## The Module System Is a Performance Lever

Under Lean's module system (4.21+), a definition's *body* has its own visibility, separate from its name:

- `def` bodies are **not exposed** by default. Downstream modules see the name and the type, and must reason through your lemmas.
- `abbrev` bodies **are exposed** by default.
- `@[expose]` opts a `def` in. `@[no_expose]` opts back out, including inside an `expose` section.

`@[expose]` is a performance decision, not a convenience. It grants every downstream file permission to unfold the body — and typeclass search, `simp`, and `isDefEq` will take that permission whether or not you wanted them to.

Expose a body when downstream code genuinely computes with it. Otherwise, seal it and export the equation lemmas. The `warn.redundantExpose` option flags `@[expose]` and `@[no_expose]` annotations that change nothing.

Because unexposed bodies stop at the module boundary, sealing also shrinks what a downstream edit can invalidate.

## Register the Instance Once

If the same `haveI` shows up in two proofs, it is an instance:

```lean
-- Repeated in proof after proof, each paying the full derivation:
haveI : (widget k hk).IsInner := by
  dsimp [widget, widgetData]
  simp only [hkn, dif_pos]
  infer_instance
```

Write it once, at the top level, in terms of the equation lemmas:

```lean
instance widget_isInner (hkn : k.1 < n) : (widget k hk).IsInner := by
  rw [widget_of_lt hkn]; infer_instance
```

Every later proof now finds it by search, at the cost of one lookup. The derivation happened once, when you compiled this line.

The signal to watch is the diagnostics section `type_class: used instances`. A high count for one instance means Lean rebuilt the same thing repeatedly.

## Shaping Instance Terms

Typeclass search is fast when instance terms are *canonical* — when the projection out of a big instance is literally the small instance Lean already has, rather than something that must be unfolded to match.

- **`inferInstanceAs`** finds an instance for a definitionally equal type without re-searching. Mathlib leans on it heavily.

    ```lean
    instance : Monoid MyType := inferInstanceAs (Monoid Underlying)
    ```

- **`fast_instance%`** (Mathlib) rebuilds an instance as nested constructor applications that point at the instances you already have. Its own rationale: define `instRing` with `fast_instance%` and `instRing.toSemiring` "unifies almost immediately with `instSemiring`, rather than having to break it down into smaller pieces."

    ```lean
    instance instRing : Ring X := fast_instance% Function.Injective.ring ..
    ```

- **Shortcut instances** name a common composite directly so search does not walk the hierarchy to rebuild it. Mathlib marks many, with comments like `-- shortcut instance for performance reasons`.

- **Priorities.** Give broad derived instances low priority so they are tried last, as in `instance (priority := 100)`.

    ```lean
    instance (priority := 100) : SomeBroadClass A := ...
    ```

## Withholding Instances

A true fact is not automatically a good instance. Mathlib often marks one "not an instance for performance reasons". Withhold it when the fact is broad, expensive to derive, or creates a second path to a structure that already has one:

```lean
-- Named theorem, installed locally only where it is needed.
theorem myType_isArtinian : IsArtinian R M := ...

-- At the use site:
attribute [local instance] myType_isArtinian in
theorem uses_it : ... := ...
```

Competing inherited data — two routes to the same zero, the same scalar action, the same topology — makes `infer_instance`, `simp`, and definitional equality fragile as well as slow. Before you make one class extend another, check what fields both already carry.

## `@[irreducible]`, `seal`, `unseal`

`@[irreducible]` stops unfolding everywhere. Mathlib's stated reason, from `Mathlib/Algebra/MonoidAlgebra/Defs.lean`: "We make it irreducible so that Lean doesn't unfold it when trying to unify two different things." From `FractionalIdeal/Basic.lean`: "so by making definitions irreducible, we hope to avoid deep unfolds."

`seal foo` marks `foo` irreducible after the fact; `unseal foo in` lets a single declaration see through it. Use `unseal` where you genuinely must compute, and nowhere else.

Definitions by well-founded recursion are `@[irreducible]` by default since Lean 4.9, because unfolding one forces the kernel to reduce its termination proof. Do not remove that.

Reach for `@[irreducible]` when the body is an implementation detail, when unfolding it is expensive, or when the diagnostics show `kernel: unfolded declarations` climbing. Prefer sealing by module visibility first: it costs nothing and stops the unfolding at the boundary.

## Worked Example

The three mistakes compound. Here they are together, and then apart.

**Before.** A data `def` in tactic mode, exposed, projected through a reducible `abbrev`:

```lean
@[expose]
def widgetData (k : Fin (n + 1)) (hk : 0 < k.1) : { W : Widget n k // W.IsProper } := by
  by_cases hkn : k.1 < n
  · exact ⟨innerWidget hkn, inferInstance⟩
  · have hlast : k = Fin.last n := by apply Fin.ext; simp; omega
    subst hlast
    exact ⟨edgeWidget hk, inferInstance⟩

abbrev widget (k : Fin (n + 1)) (hk : 0 < k.1) : Widget n k := (widgetData k hk).1
```

Every proof about `widget` now opens with the same six lines, because there is no other way in:

```lean
haveI : (widget k hk).IsInner := by
  dsimp [widget, widgetData]
  simp only [hkn, dif_pos]
  infer_instance
```

Repeat that at six sites and you pay for the derivation six times. Note what that costs and what it does not. In a real file with this pattern, the six sites together accounted for well under a second — the elaborator is faster at this than you would guess. What they cost is legibility and churn: the definition has no usable interface, so every proof invents one, and every change to the definition breaks all six.

Fix it because it is the right shape, and measure before you claim a speedup. If the profiler blames `typeclass inference` or `elaboration`, this will help. If it blames `type checking`, the kernel is grinding on your proof terms and you want `term-size-and-transparency.md` instead.

**After.** Term-mode body, sealed, with its equations and instance named once:

```lean
def widget (k : Fin (n + 1)) (hk : 0 < k.1) : Widget n k :=
  if hkn : k.1 < n then innerWidget hkn else edgeWidget (lastOfNotLt hkn)

theorem widget_of_lt (hkn : k.1 < n) : widget k hk = innerWidget hkn := dif_pos hkn
theorem widget_of_not_lt (hkn : ¬ k.1 < n) : widget k hk = edgeWidget _ := dif_neg hkn

instance widget_isProper : (widget k hk).IsProper := by
  unfold widget; split <;> infer_instance

instance widget_isInner (hkn : k.1 < n) : (widget k hk).IsInner := by
  rw [widget_of_lt hkn]; infer_instance
```

The six-line preamble disappears from every proof: the instance is found by search, and any proof that needs the body rewrites with `widget_of_lt`. The derivation runs once, here.

Note what did *not* change: no tactic got faster, no heartbeat limit moved, no import was dropped. The work simply stopped happening more than once.

## Related

- `references/profiling-and-diagnostics.md` — the counters that reveal each of these problems
- `references/term-size-and-transparency.md` — the transparency table and olean size
- The `deep-module-design` skill — sealing a definition is a narrow interface over a deep implementation
