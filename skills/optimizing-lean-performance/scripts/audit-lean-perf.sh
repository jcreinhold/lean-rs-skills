#!/usr/bin/env bash
# Audit Lean 4 sources for shapes that cost compile time.
#
# This is a smell detector, not a profiler. It cannot tell you where the time
# goes -- only where it tends to go. Profile before you act on anything here:
#
#   lake env lean -Dprofiler=true -Dprofiler.threshold=250 <file>
#
# Usage: bash audit-lean-perf.sh <file-or-directory> [...]

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $(basename "$0") <file-or-directory> [...]" >&2
  exit 2
fi

# Collect Lean sources from the given paths.
files=()
for target in "$@"; do
  if [ -d "$target" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$target" -name '*.lean' -not -path '*/.lake/*' | sort)
  elif [ -f "$target" ]; then
    case "$target" in
      *.lean) files+=("$target") ;;
      *) echo "skipping non-Lean file: $target" >&2 ;;
    esac
  else
    echo "no such path: $target" >&2
    exit 2
  fi
done

if [ "${#files[@]}" -eq 0 ]; then
  echo "no .lean files found" >&2
  exit 2
fi

# Warn if this does not look like a Lean package; imports may not resolve when
# the reader goes to profile.
root="${1%/*}"
while [ -n "$root" ] && [ "$root" != "/" ]; do
  if compgen -G "$root/lakefile.*" > /dev/null 2>&1; then break; fi
  root="${root%/*}"
done

# Counters, for the closing summary.
n_term=0 n_kernel=0 n_iface=0 n_unsound=0

# Report the lines of `file` matching `pattern` under `header`, and add the
# count to the named counter. `note` explains what the match means.
# Prints the file name once, lazily, before its first hit.
scan() {
  local file="$1" pattern="$2" header="$3" note="$4" counter="$5"
  local out n lines
  out="$(grep -nE "$pattern" "$file" || true)"
  [ -z "$out" ] && return 0
  if [ "$shown" != "$file" ]; then printf '\n%s\n' "$file"; shown="$file"; fi
  n="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  lines="$(printf '%s\n' "$out" | cut -d: -f1 | tr '\n' ' ')"
  printf '  %-28s %s\n' "$header" "(${n}) lines: ${lines% }"
  printf '      %s\n' "$note"
  eval "$counter=\$(( $counter + n ))"
}

echo "Lean performance audit: ${#files[@]} file(s)"

shown=""
for f in "${files[@]}"; do
  # --- Proof-term size: what the kernel pays for. -------------------------
  scan "$f" '^[[:space:]]+let [A-Za-z_].*:=' \
    'tactic let' \
    'let-bound term is expanded into the proof term; later have-types re-embed it. Hoist to a top-level def.' \
    n_term
  scan "$f" '(^|[[:space:]])convert!?[[:space:]]' \
    'convert' \
    'congruence + HEq obligations over dependent types; large term to check. rw into shape, then exact.' \
    n_term
  scan "$f" '(^|[[:space:]])simpa[[:space:]]*\[' \
    'simpa with lemmas' \
    'simplifies goal and the using-term, then checks defeq. Costly on large structures.' \
    n_term

  # --- Definition shape: what the elaborator keeps unfolding. -------------
  # A declaration's signature may wrap over several lines, so join each
  # `def`/`abbrev` header up to its `:=` before deciding.
  scan_decl() {
    local file="$1" kw="$2" rhs="$3" header="$4" note="$5" counter="$6"
    local out n lines
    out="$(awk -v kw="$kw" -v rhs="$rhs" '
      /^[[:space:]]*(@\[|--|\/-)/ { next }
      buf == "" && $0 ~ "^(noncomputable[ \t]+)?(private[ \t]+)?(protected[ \t]+)?" kw "[ \t]" { buf = $0; ln = NR }
      buf != "" && buf !~ /:=/ && NR > ln { buf = buf " " $0 }
      buf ~ /:=/ {
        body = buf; sub(/^.*:=/, "", body)
        if (body ~ /^[ \t]*$/) { getline; body = $0 }
        if (body ~ rhs) print ln
        buf = ""
      }
    ' "$file" || true)"
    [ -z "$out" ] && return 0
    if [ "$shown" != "$file" ]; then printf '\n%s\n' "$file"; shown="$file"; fi
    n="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
    lines="$(printf '%s\n' "$out" | tr '\n' ' ')"
    printf '  %-28s %s\n' "$header" "(${n}) lines: ${lines% }"
    printf '      %s\n' "$note"
    eval "$counter=\$(( $counter + n ))"
  }

  scan_decl "$f" 'def' '^[ \t]*by[ \t]*$' \
    'data def in tactic mode' \
    'body becomes dite under Eq.mpr motive scaffolding; nothing reduces it cheaply. Write it in term mode.' \
    n_iface
  scan_decl "$f" 'abbrev' '[.(]' \
    'abbrev of a compound term' \
    'abbrev is reducible, so this term is re-inlined on every defeq check. Make it a def.' \
    n_iface
  scan "$f" '^@\[expose\]' \
    'exposed body' \
    'grants every downstream file permission to unfold the body. Seal it and export lemmas.' \
    n_iface
  scan "$f" '^[[:space:]]+(haveI|letI)[[:space:]]*:' \
    'local instance in a proof' \
    'if this appears in two proofs it is an instance. Register it once.' \
    n_iface
  scan "$f" '^[[:space:]]+dsimp[[:space:]]*\[|^[[:space:]]+unfold[[:space:]]' \
    'unfolding a definition by hand' \
    'the definition is missing equation lemmas. Prove them once and rw.' \
    n_iface

  # --- Kernel reduction. --------------------------------------------------
  scan "$f" '(^|[[:space:]])(decide|native_decide)[[:space:]]*$' \
    'kernel evaluation' \
    'decide evaluates in the kernel; cost lands in the type-checking phase.' \
    n_kernel

  # --- Soundness and hygiene: never commit these. -------------------------
  scan "$f" '(^|[[:space:]])native_decide' \
    'UNSOUND: native_decide' \
    'trusts the whole compiler, not the kernel. Mathlib bans it; False is reportedly provable with it.' \
    n_unsound
  scan "$f" '^set_option[[:space:]]+maxHeartbeats' \
    'unscoped maxHeartbeats' \
    'scope it with `in` and comment why, or fix the real cost.' \
    n_unsound
  scan "$f" '^set_option[[:space:]]+maxHeartbeats[[:space:]]+0([[:space:]]|$)' \
    'UNSOUND-ish: maxHeartbeats 0' \
    'removes the timeout instead of the cause.' \
    n_unsound
  scan "$f" '^set_option[[:space:]]+debug\.skipKernelTC' \
    'UNSOUND: debug.skipKernelTC' \
    'skips kernel type checking. A diagnostic only; never commit it.' \
    n_unsound
  scan "$f" '^set_option[[:space:]]+(trace|profiler|pp|debug)\.' \
    'committed diagnostic option' \
    'development-only. Mathlib lints these out of committed code.' \
    n_unsound
done

cat <<SUMMARY

Orient
------
  proof-term size    ${n_term}  -> references/term-size-and-transparency.md
  definition shape   ${n_iface}  -> references/definitions-and-instances.md
  kernel reduction   ${n_kernel}  -> references/term-size-and-transparency.md
  unsound / hygiene  ${n_unsound}  -> fix before committing

These are smells, not measurements. A file can score badly and compile fast, or
score cleanly and spend twenty seconds in the kernel on one theorem. Profile:

  lake env lean -Dprofiler=true -Dprofiler.threshold=250 <file>

If the cumulative table blames 'type checking', confirm with
-Ddebug.skipKernelTC=true and then shrink the proof term.
SUMMARY
