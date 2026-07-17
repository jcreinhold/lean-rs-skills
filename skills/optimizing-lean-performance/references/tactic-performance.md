# Tactic Performance

Prefer direct terms and known rewrites to search.

1. Use `exact` or a constructor when the term is known.
2. Use `rw` for named equalities.
3. Use `simp only [...]` when a bounded simplification is needed; use `simp?` to discover the set. Use `dsimp` first for definitional equality. Remove a costly lemma locally with `attribute [-simp] lemma in`.
4. Use decision procedures only when their domain matches the goal.
5. Treat broad search (`simp`, `aesop`, large `apply` trees) as a measured choice.

Avoid `convert` on dependent terms when rewrites can align the goal first. Avoid `simpa [heavy_def]` when an equation lemma and `exact` work. Bind expressions with side effects or costly reduction once. If cost grows rapidly with input, reduce the search space or split the statement before raising limits. For a mutual inductive relation, use `cases` when a case split suffices; `induction` builds motives for every family. Split an oversized mutual block if its families do not need one recursor.
