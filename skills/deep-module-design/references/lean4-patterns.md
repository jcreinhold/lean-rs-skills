# Lean 4 Boundary Patterns

| Mixed concern | Prefer |
| --- | --- |
| State and identity | Separate an index or key from changing data. |
| Mechanism and policy | Keep policy in a parameter only when callers vary it. |
| Storage and domain logic | Keep representation `private`; export domain lemmas and operations. |
| Traversal and computation | Separate a reusable traversal from its result-specific work. |
| Error and normal path | Use a total result when the edge case is safe. |
| Interface and representation | Export equations; avoid forcing callers to unfold a `def`. |
| Caller knowledge and logic | State general lemmas rather than caller-shaped ones. |
| Ordered steps | Use indexed types or scoped APIs to make invalid states unavailable. |
| Known family and generic wrapper | Use the concrete structure until a second use needs abstraction. |
| Ordering and logic | Keep an order relation or proof separate from domain operations. |

Check that each namespace and non-`private` declaration hides a real decision.
