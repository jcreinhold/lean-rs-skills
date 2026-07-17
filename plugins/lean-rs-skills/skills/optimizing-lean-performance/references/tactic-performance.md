# Tactic Performance

Prefer direct terms and known rewrites to search.

1. Use `exact` or a constructor when the term is known.
2. Use `rw` for named equalities.
3. Use `simp only [...]` when a bounded simplification is needed; use `simp?` to discover the set.
4. Use decision procedures only when their domain matches the goal.
5. Treat broad search (`simp`, `aesop`, large `apply` trees) as a measured choice.

Avoid `convert` on dependent terms when rewrites can align the goal first. Avoid `simpa [heavy_def]` when an equation lemma and `exact` work. Bind expressions with side effects or costly reduction once. If cost grows rapidly with input, reduce the search space or split the statement before raising limits.
