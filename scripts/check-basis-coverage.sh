#!/bin/sh
# Verify that the Basis Library suite covers the specification: every value
# and exception that a signature of tests/basis/spec-sigs specifies has a
# check in tests/basis whose label starts with "Structure.member/". (Types are
# checked by matching the structure against the signature.)
#   scripts/check-basis-coverage.sh [-v]
# The structures a signature describes are those matched against it,
#   structure C : SPEC_LIST = List
#   structure C : SPEC_CHAR where type char = char = Char
# (on one line) in the tests/basis/*_sig.sml files; a signature that no test matches
# against anything is itself reported. Members of a substructure that the
# signature specifies (`structure Math : MATH`) belong to the signature of the
# substructure. -v lists the members found per structure.
#
# A structure that the specification defines as another one is declared in
# its *_sig.sml test, next to the checks that the types are shared:
#   (* alias: LargeInt = IntInf *)
# and is covered by the checks of that structure.
#
# A test functor of tests/basis/fn builds its labels with `lab "member/case"`,
# which stands for NAME.member/case in every application
#   structure Generic = TestIntegerFn (structure I = Int val name = "Int")
set -u
verbose=0
[ "${1:-}" = -v ] && verbose=1
cd "$(dirname "$0")/.."
suite=tests/basis
status=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# Every label of the suite, once: the text between `("` and the first `/`
# (the member `/` itself gives "Real.//case").
{
  cat "$suite"/*.sml | grep -o '"[A-Za-z0-9_.]*\.[^"/ ]*/' | tr -d '"' | sed 's|/$||'
  cat "$suite"/*.sml | grep -o '"[A-Za-z0-9_.]*\.//' | tr -d '"' | sed 's|//$|/|'
  cat "$suite"/*.sml |
    sed -n 's/.*= *\(Test[A-Za-z0-9]*Fn\) *(.*val name = "\([^"]*\)".*/\1 \2/p' |
    while read -r functor name; do
      file=$(grep -l "^functor $functor\>" "$suite"/fn/*.sml | head -1)
      [ -n "$file" ] || continue
      grep -o 'lab "[^"/ ]*/' "$file" | sed -e 's/^lab "//' -e 's|/$||' -e "s|^|$name.|"
      grep -o 'lab "//' "$file" | sed "s|.*|$name./|"
    done
} | sort -u > "$tmp/labels"

# members FILE SIGNATURE: the val and exception names the signature specifies.
# A member of a substructure specified in place, `structure O : sig ... end`,
# is named O.member (on one line or several).
members() {
  awk -v sig="$2" '
    # drop comments, which nest
    { line = $0; out = ""
      while (length(line) > 0) {
        if (substr(line, 1, 2) == "(*") { depth++; line = substr(line, 3); continue }
        if (depth > 0 && substr(line, 1, 2) == "*)") { depth--; line = substr(line, 3); continue }
        if (depth == 0) out = out substr(line, 1, 1)
        line = substr(line, 2)
      }
      $0 = out }
    $1 == "signature" && $2 == sig { on = 1; body = 0; n = 0 }
    on {
      for (i = 1; i <= NF; i++) {
        t = $i
        if (t == "signature" && i + 1 <= NF && $(i + 1) != sig && body) { on = 0; break }
        if (t == "structure" && i + 1 <= NF) { pending = $(i + 1); continue }
        if (t == "sig") {
          if (!body) { body = 1; pending = ""; continue }
          stack[++n] = pending; pending = ""; continue
        }
        if (t == "end") {
          if (n > 0) { n--; continue }
          if (body) { on = 0; break }
        }
        if ((t == "val" || t == "exception") && i + 1 <= NF) {
          prefix = ""
          for (k = 1; k <= n; k++) if (stack[k] != "") prefix = prefix stack[k] "."
          print prefix $(i + 1)
        }
      }
    }
  ' "$1" | sort -u
}

count=0
missing=0
for spec in "$suite"/spec-sigs/*.sml; do
  for sig in $(sed -n 's/^signature \(SPEC_[A-Z0-9_]*\).*/\1/p' "$spec"); do
    # `structure C : SIG = S` or `structure C : SIG where type ... = S`
    structures=$(cat "$suite"/*_sig.sml |
      sed -n "s/^[[:space:]]*structure [A-Za-z0-9_]* :>* *$sig\( .*\)* = \([A-Za-z0-9_.][A-Za-z0-9_.]*\)[[:space:]]*$/\2/p" | sort -u)
    if [ -z "$structures" ]; then
      echo "check-basis-coverage: no $suite/*_sig.sml matches a structure against $sig (${spec#"$suite"/})"
      status=1
      continue
    fi
    members "$spec" "$sig" > "$tmp/members"
    for s in $structures; do
      alias=$(cat "$suite"/*_sig.sml | sed -n "s/^[[:space:]]*(\* alias: $s = \([A-Za-z0-9_.]*\) \*)[[:space:]]*$/\1/p" | head -1)
      if [ -n "$alias" ]; then
        [ $verbose = 1 ] && echo "$s : $sig (covered by $alias)"
        continue
      fi
      [ $verbose = 1 ] && echo "$s : $sig ($(wc -l < "$tmp/members" | tr -d ' ') members)"
      while read -r m; do
        count=$((count + 1))
        if ! grep -q -x -F "$s.$m" "$tmp/labels"; then
          echo "check-basis-coverage: no check labelled \"$s.$m/...\" ($sig in ${spec#"$suite"/})"
          missing=$((missing + 1))
          status=1
        fi
      done < "$tmp/members"
    done
  done
done

if [ $status = 0 ]; then
  echo "check-basis-coverage: OK ($count specified members have checks)"
else
  echo "check-basis-coverage: $missing of $count specified members have no check"
fi
exit $status
