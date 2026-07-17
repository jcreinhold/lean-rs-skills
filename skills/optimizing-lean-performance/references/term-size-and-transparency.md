# Term Size and Transparency

The kernel checks the proof term, not the tactic script. It ignores elaborator transparency attributes.

- Split repeated or large derivations into named lemmas.
- Avoid large tactic-mode `let` bindings that appear in later proposition types.
- Rewrite goals into shape before `exact` rather than using costly dependent conversion.
- Reduce unrestricted search to its resulting rewrites.
- Use `noncomputable` for proof-only definitions that do not need code generation.
- Use irreducibility only after measuring; it can move cost to callers that need to unfold.

Large oleans usually indicate large stored terms. Find the owning declarations, factor them, then rebuild and measure.
