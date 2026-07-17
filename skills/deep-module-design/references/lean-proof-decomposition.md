# Designing Proofs: Mathematical Decomposition in Lean 4

Read this when the module you are designing is a body of Lean proofs — theorems, lemmas, and definitions — rather than data-carrying code. The deep-module principles still apply (statement = interface, proof = hidden implementation, lemma = function), but proofs have a second axis the software principles are blind to: a proof can be deep, uncomplected, and `lake build`-green while still proving the *wrong mathematical thing* or splitting the work in a way no mathematician would recognize. This file supplies that axis.

The governing rule: **when the two frames conflict, the mathematics wins.** A definition a mathematician recognizes instantly beats a "deeper" but unrecognizable encoding; a lemma stated the way it is used beats a lemma stated for the convenience of its proof.

The material is general mathematical craft (Tao, Lamport, Leron, Halmos, Leinster/Riehl). The Lean and category-theory examples are illustrations — mathlib is heavily categorical — not the only setting the guidance applies to.

## Table of Contents

1. [Fix the statement before the proof](#fix-the-statement-before-the-proof)
2. [Level audit: the forgetful-object test](#level-audit-the-forgetful-object-test)
3. [Choose the right unit of work](#choose-the-right-unit-of-work)
4. [State lemmas for use, not for proof](#state-lemmas-for-use-not-for-proof)
5. [The top-level proof is assembly](#the-top-level-proof-is-assembly)
6. [Closing is not correct: the two acceptance tests](#closing-is-not-correct-the-two-acceptance-tests)
7. [Writing mechanics: structured proofs](#writing-mechanics-structured-proofs)
8. [Mathematical smells](#mathematical-smells)
9. [Where the mathematics beats the generic heuristic](#where-the-mathematics-beats-the-generic-heuristic)

______________________________________________________________________

## Fix the statement before the proof

The statement is the interface. Getting it right is the design task; the proof is the implementation that gets hidden behind it. Before writing a single tactic, pin down three things and put them in the statement (or in the ambient setup right beside it):

- **The ambient setting** — the category, the ring, the space, the universe, the typeclass instances actually in play.
- **The exact quantifiers and domains** — no "obvious" omissions. `∀ x`, over what? An existential over which domain?
- **The kind of comparison** — the relation the theorem actually proves: equality, isomorphism (`≅`), equivalence (`≃`), homotopy, inclusion (`⊆`), factorization, or an order relation. Many proof errors are *kind-of-comparison* errors: equality asserted where only isomorphism holds.

A theorem statement should be exact and citable on its own: include every hypothesis the proof uses, keep proof-only temporary notation out of the statement, and put motivation just before or after — never inside — the statement. If the statement and the definitions it mentions are not yet stable, this is not yet a design task; stabilize them first.

______________________________________________________________________

## Level audit: the forgetful-object test

This is the statement-level form of "typechecks but isn't the math," and it has no software analogue. Before you invest in a decomposition, check that the theorem is substantive **on the exact object**, not on a *forgetful object* — a quotient, classifier, invariant, or summary that deliberately forgets some of the data.

Ask:

- Is the statement substantive on the exact object, or only on a forgetful object (its `π₀`, its underlying set, its isomorphism class, some numeric invariant)?
- Does a trivial mediator or a stand-in choice make the claim immediate?
- Does the live mathematical content sit in data the current formulation omits?

If the theorem has collapsed onto a forgetful object, **stop adding lemmas at that level.** Classify the result:

- **false at this level** — the honest statement is stronger and does not hold as written;
- **tautological at this level** — the forgetful projection makes it immediate, so it is not the theorem you meant;
- **substantive only at a richer level** — restate on the object that still carries the content.

A green `lake build` on a collapsed statement is the most dangerous outcome: it looks like progress and proves nothing of interest.

______________________________________________________________________

## Choose the right unit of work

This is how a mathematician splits the work — the proof analogue of drawing module boundaries. Each unit should remove **one** source of difficulty. Pick the smallest unit that does the job:

- **Milestone proposition** — a conceptual turning point: cited more than once, or the claim that makes the main theorem mostly formal once proved. Give it its own name and its own review attention. Promote a lemma to a proposition (or its own section) the moment it becomes a conceptual hinge or its proof carries independent weight.
- **Local lemma** — removes one technical obstacle cleanly and can be forgotten after use. Keep it close to where it is used.
- **Sublemma inside a proof** (a `have`) — the intermediate claim matters only inside that one proof. Do not lift it to a named lemma.
- **Merge** — if a pair of technical lemmas is only useful together, and the bridge statement between them is verified once and used once, unify them into a single lemma (Tao).

Good decomposition removes one source of difficulty per lemma. Bad decomposition either mixes unrelated jobs into one lemma (under-split) or manufactures labels the reader must remember for no payoff (over-split, *lemma-itis*). A test: if you cannot describe a lemma in one meaningful sentence, it is doing too many jobs; if a lemma is used once and its body is shorter than its statement, inline it.

Before drafting the top-level proof, make the dependency order explicit — even a short bullet DAG. If you cannot say which subclaims would make the theorem routine, you do not yet understand the proof plan; step back before drafting.

______________________________________________________________________

## State lemmas for use, not for proof

Tao's rule: *state a lemma in the form that is easiest to use, not easiest to prove.* Concretely:

- **Natural hypotheses, manifestly useful conclusion, minimal notation.** Push disposable notation, local calculations, and purely internal bridge claims down into the proof.
- **Generality is dictated by callers, not by the proof.** State the lemma at the type actually used; generalize to `α : Type*` with a stack of typeclass constraints only when a *real* second caller arrives — callers decide generality, not the convenience of the current proof. This is the proof form of core principle §6 ("interface reflects multiple uses; functionality reflects current needs") and the antidote to reflexive `Type*` polymorphism.
- **Names are part of the interface.** `aux1`, `helper2`, `step` are naming amnesia — a caller has to read the body to know what the lemma gives them. Pay for a name that states the fact.

The point is not to maximize lemma count. It is to make the main theorem approachable and turn the final proof into an assembly of already-understood moves.

______________________________________________________________________

## The top-level proof is assembly

Pull complexity downward, in proof clothing. Once the enabling lemmas are proved, the top-level proof should mostly invoke them in a controlled order — introduce hypotheses, cite the milestone propositions, discharge the routine residue. If, after decomposition, the top-level proof still reads as a heroic direct attack — long `calc` chains, nested case splits, ad-hoc `have`s doing real work — the decomposition is **unfinished**, not the proof. Go back and name the missing lemma.

______________________________________________________________________

## Closing is not correct: the two acceptance tests

The elaborator turning green is not evidence the proof is correct — it is evidence the tactics type-checked. Lamport's confirmation-bias warning bites hardest for an agent, because *closing the goal is the training signal*: the desire to confirm the goal is closed will cause you to miss gaps. Run two independent tests before declaring a proof designed:

- **Leron-test (comprehensibility).** Read the proof at speed, skipping every subclaim body. Does it still read as mathematics — a coherent sketch you could narrate? If the skeleton only makes sense with the bodies filled in, the decomposition is not carrying the argument; it is one paragraph wearing lemma costumes.
- **Lamport-test (correctness).** Check, line by line, that: every symbol is defined before use; every hypothesis is used at the point it matters; every case split is exhaustive on the *right* object; every existential witness is actually constructed; every uniqueness claim states its kind of comparison; and every "clearly" / "by inspection" survives a skeptical read.

______________________________________________________________________

## Writing mechanics: structured proofs

Once the decomposition is right, the mechanics of writing each proof body should preserve the structure, not dissolve it into tactic soup. Write **statement-first**: name each intermediate claim before proving it, so the outline is checkable before you commit body detail. Lamport's expansion rule — *expand the proof until the lowest-level statements are obvious, then continue for one more level* — is the stopping criterion.

Lamport's hierarchical-proof primitives map onto Lean tactic mode:

| Lamport primitive | Lean tactic | role |
| --- | --- | --- |
| `ASSUME` / `PROVE` | `intro` | discharge a hypothesis, expose the goal |
| `NEW x` | `intro x` | introduce a fresh variable |
| `SUFFICES` | `suffices` | reduce the goal to a stronger/simpler claim |
| `PICK` | `obtain` | name a witness from an existential |
| `CASE` | `rcases` / `match` | split exhaustively on a disjunction or constructor |
| named step | `have h : … := …` | assert a sublemma with a hideable proof |

Prefer `have` / `suffices` / `calc` skeletons whose named steps read as the sketch the Leron-test wants. A `calc` chain should narrate the kind of comparison at each link (`=`, `≅`, `≃`, `⊆`) rather than silently mixing them.

**Boundary.** This file covers *structuring* the proof — the shape of the argument. The tactic-driving loop itself (one step at a time, error-priority ordering, working the hardest case first, dependent-rewrite fixes) belongs to the `lean-proof` skill. Hand off to it once the decomposition and the statement-first skeleton are in place.

______________________________________________________________________

## Mathematical smells

Each smell is a proof that may close while failing to be the mathematics you intended. Fix the underlying gap, not the symptom.

| Smell | What it means | Fix direction |
| --- | --- | --- |
| Equality claimed, only isomorphism proved | Kind-of-comparison mismatch | Restate with `≅` / `≃`; only write `=` if the framework has chosen a strict representative |
| Conclusion stronger than the proof establishes | The statement oversells the argument | Weaken the statement to what is proved, or strengthen the proof |
| Hidden quantifier or unstated ambient hypothesis in the statement | The theorem is not citable on its own | Move every used hypothesis and quantifier into the statement |
| Case split that is not exhaustive on the right object | A branch is silently assumed away | Split on the object the claim is about; cover every constructor/disjunct |
| Uniqueness proves "at most one" but never existence | Half of an existence-and-uniqueness claim | Construct the witness explicitly, then prove it unique |
| Universal-property argument gives the map but not its uniqueness | The universal property is only half-invoked | Prove the mediating map is *the* unique one, not just *a* map |
| Canonical isomorphism treated as literal equality | Coherence data discarded | Track the isomorphism; do not rewrite along it as `=` |
| Milestone buried as an unremarkable lemma, or a one-use lemma promoted with no payoff | Decomposition mismatched to mathematical weight | Promote conceptual hinges; inline disposable one-use claims |
| Reflexive `Type*` generality with unused typeclass constraints | Generality serving the proof, not a caller | State at the type used; generalize when a real second caller appears |

______________________________________________________________________

## Where the mathematics beats the generic heuristic

When a proof-design choice and a software heuristic point in different directions, prefer the mathematically legible option:

- **Recognizability over raw depth.** A definition stated via its universal property is what a mathematician reaches for, even when a lower-level encoding would score a higher depth ratio. If the object is defined categorically, prefer the universal property to the construction — it replaces element-chasing with one existence check and one uniqueness check, and later proofs reduce to what happens on generators.
- **Use-shape over proof-convenience.** Leinster/Riehl: state a result the way it will be *used*. That overrides the temptation to phrase it however made the proof shortest.
- **Standard vocabulary over invented structure.** Reach for the block a mathematician would name — theorem, proposition, lemma, corollary, definition, example, remark — rather than a bespoke bundling that happens to minimize surface area.

The deep-module principles are still your tools; this section is the tiebreak when they collide with what the mathematics wants.
