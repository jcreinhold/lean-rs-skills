# Designing Lean Proofs

## Fix the Statement

State the exact object, assumptions, and comparison kind before tactics. Check whether a quotient, invariant, or forgetful map makes the claim trivial. Do not claim equality when the mathematics gives an isomorphism or equivalence.

## Choose Lemmas

Split by mathematical difficulty, not by tactic steps. State each lemma in the form its callers need, with natural hypotheses and a useful conclusion. Merge lemmas that no later proof uses apart.

## Assemble

The top-level proof should apply named lemmas in the mathematical order. Name intermediate claims with `have`, `suffices`, or `calc`; do not hide the outline in one large tactic block.

## Check

- Read the outline without proof bodies. It should still state a mathematical argument.
- Check symbols, hypotheses, case splits, witnesses, and comparison types against the intended result.
- A closed Lean goal proves only that the term type-checks; it does not validate the chosen statement.

## When Rules Conflict

Prefer the definition and decomposition that mathematicians recognize over a software abstraction that merely looks smaller.
