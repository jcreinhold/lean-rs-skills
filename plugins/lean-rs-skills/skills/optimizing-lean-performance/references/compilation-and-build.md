# Compilation and Build Performance

- Use Lake parallelism appropriate to available cores; do not serialize independent modules.
- Keep imports narrow. An import adds declarations, instances, and simp rules to all dependents.
- Avoid broad re-exports; `open` affects local name resolution, while `export` grows downstream work.
- Split stable interfaces from costly implementations when it shortens rebuild paths.
- Preserve incremental builds: avoid needless changes to widely imported files.
- Refresh cached mathlib oleans after updating mathlib when the project supports them.
- For executable modules, inspect compiler options separately from proof checking; they do not speed kernel checks.

Time a full build and the affected module before changing build structure. Use the import graph to find a critical path, not to justify arbitrary file splits.
