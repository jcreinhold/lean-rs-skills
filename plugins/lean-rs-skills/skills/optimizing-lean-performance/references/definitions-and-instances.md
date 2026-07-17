# Definitions and Instances

Write data-valued definitions as terms when practical. Tactic proofs can leave large casts and motives that later reduction must cross.

When a branch chooses data, prefer a term-mode `dite` over a long tactic proof. If callers repeatedly unfold the same case split, export one equation lemma per branch instead.

- Keep a heavy body behind `def`; publish equation lemmas for its useful cases.
- Do not use `abbrev` for a term that appears in type equality: Lean inlines it.
- Avoid `@[expose]` on costly bodies. Module privacy is the cheapest boundary.
- Register a derivation used repeatedly as an instance or named fact; do not create global instances for one use.
- Shape instances so projections reuse existing canonical instances. Use `inferInstanceAs` or `fast_instance%` when diagnostics show instance unfolding.
- Give broad derived instances low priority and withhold true but costly instances that do not improve common search.

Confirm repeated derivation with the `type_class: used instances` diagnostics counter.
- Use `@[irreducible]`, `seal`, and local `unseal` only for an expensive implementation detail with a usable API.

Measure before claiming a speed gain. Better equation lemmas often improve maintainability even when timing does not move.
