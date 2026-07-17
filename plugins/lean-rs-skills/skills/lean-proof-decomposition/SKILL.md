---
name: lean-proof-decomposition
description: 'Use for planning or restructuring Lean 4 proofs: theorem statements, equality versus isomorphism or equivalence, lemma boundaries, mathematical alignment, long tactic proofs, and proof outlines before tactic implementation.'
---

# Lean Proof Decomposition

Design the statement and proof outline before tactics. Use this skill when the mathematical claim or lemma structure is unclear; use a proof-construction skill once the outline is fixed.

Read `references/proof-design.md` for the full checks and examples.

## Workflow

1. State the exact objects, assumptions, and comparison kind (`=`, `≅`, `≃`, `⊆`, or `→`).
2. Check the claim at that level. A quotient, invariant, or forgetful map must not make it trivial.
3. List the independent mathematical obstacles.
4. Introduce a milestone proposition for a major result, a local lemma for one obstacle, and a sublemma only when it has a separate reusable fact.
5. State lemmas for their callers, not for the tactic that proves them. Do not add unused `Type*` or typeclass generality.
6. Make the top-level proof apply named lemmas in mathematical order.

## Checks

- An equivalence used to prove equality usually means the statement should use `≃` or `≅`, unless the setup chose a strict representative.
- Prefer a definition mathematicians recognize and use over an encoding that merely shortens the implementation.
- Read the outline while skipping proof bodies. It should still give the argument.
- A closed Lean goal proves that the term type-checks; verify the statement against the intended mathematics.

## Before Declaring Done

- [ ] The statement names the right object and comparison.
- [ ] The level audit shows real content remains on that object.
- [ ] Each lemma removes one obstacle and has a useful name and conclusion.
- [ ] The top level is assembly, not a single tactic attack.
- [ ] The proof passes a skeptical check of assumptions, cases, witnesses, and comparison types.
