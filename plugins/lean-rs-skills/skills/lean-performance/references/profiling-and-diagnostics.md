# Profiling and Diagnostics

Start with `set_option profiler true` and read cumulative phase time. Use `set_option trace.profiler true` only after you know tactic execution is the cost.

| Question | Tool |
| --- | --- |
| Which phase costs time? | `set_option profiler true` |
| What is unfolded or searched repeatedly? | `set_option diagnostics true` |
| Which tactic costs time? | `set_option trace.profiler true` |
| Did one proof improve? | `#count_heartbeats in` |

Key diagnostics: reducible unfolding suggests `abbrev`; ordinary unfolding suggests a sealed `def` with equation lemmas; instance unfolding or pending failures suggests instance shaping or a simpler type; kernel unfolding suggests a smaller proof term. Counters locate work but do not measure elapsed time.

Minimize a slow file by timing prefixes or extracting the declaration. Re-profile after each change. Use a heartbeat count as a regression guard, not as a target for a tight global limit.
