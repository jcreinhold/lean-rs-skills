# Lean Proof Design

## Statement First

Fix the ambient assumptions, objects, and comparison before proving anything. Equality needs chosen identical terms; isomorphism or equivalence preserves structure without that choice. If a proof repeatedly rewrites along an equivalence, reconsider the statement.

Run a level audit: identify the exact object that carries the claim, then ask whether passing to a quotient, invariant, or forgetful image makes it automatic. If so, either restate the substantive claim or label the weaker claim honestly.

## Lemma Boundaries

Use a milestone proposition for a visible stage of the argument, a local lemma for one technical obstacle, and a sublemma for a fact used independently. Do not split by tactic commands. Merge a lemma that only bridges two adjacent steps and has no useful caller-facing statement.

State each lemma with natural hypotheses and a conclusion its callers can use. Avoid `aux1`, `helper2`, and unused polymorphism. Generalize only when another caller needs it.

## Proof Outline

Write the top level as named claims with `have`, `suffices`, and `calc`. Each claim should move the mathematical argument forward. A quick outline read that skips subproofs should still explain why the theorem holds.

## Skeptical Check

Check every symbol before use, each hypothesis where it matters, exhaustive cases on the right object, constructed witnesses, and the kind of each comparison. Lean's acceptance does not verify that the statement expresses the intended mathematics.
