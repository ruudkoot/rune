#!/bin/sh
# Verify that documentation, tests and definition files are in sync:
#  1. every docs/language.md row marked Supported/Partial has a test
#     tests/lang/<id>_*.sml; for a row basis.<name> a test of the Basis
#     Library suite, tests/basis/<name>.sml or tests/basis/<name>_*.sml, will
#     do as well;
#  2. every tests/lang/<id>_*.sml has a row <id> in docs/language.md, and
#     every tests/basis/<name>[_*].sml a row basis.<name>;
#  3. every opcode in vm/opcodes.def and primitive in vm/prims.def is mentioned
#     in docs/bytecode.md;
#  4. every top-level structure in lib/basis/*.sml is mentioned in docs/language.md;
#  5. every basis file listed in lib/basis/MANIFEST exists (and vice versa).
set -u
cd "$(dirname "$0")/.."
status=0
fail() { echo "check-docs: $1"; status=1; }

doc=docs/language.md
rows=$(grep -E '^\| [a-z][a-z0-9.]* \|' "$doc" | sed 's/^| \([^ ]*\) |.*/\1/')
tested=$(grep -E '^\| [a-z][a-z0-9.]* \|' "$doc" | grep -E '\| (Supported|Partial) \|' | sed 's/^| \([^ ]*\) |.*/\1/')

# 1. documented features need tests
for id in $tested; do
  ls tests/lang/"$id"_*.sml > /dev/null 2>&1 && continue
  case "$id" in
    basis.*)
      name=${id#basis.}
      [ -f "tests/basis/$name.sml" ] && continue
      ls tests/basis/"$name"_*.sml > /dev/null 2>&1 && continue
      ;;
  esac
  fail "feature '$id' is documented as implemented in $doc but has no test tests/lang/${id}_*.sml"
done

# duplicate ids
dups=$(echo "$rows" | sort | uniq -d)
[ -n "$dups" ] && fail "duplicate feature ids in $doc: $dups"

# 2. tests need documentation
for f in tests/lang/*.sml; do
  id=$(basename "$f" .sml | sed 's/_.*//')
  if ! echo "$rows" | grep -qx "$id"; then
    fail "test $f has no row '$id' in $doc"
  else
    if ! echo "$tested" | grep -qx "$id"; then
      fail "test $f exists but '$id' is not marked Supported or Partial in $doc"
    fi
  fi
done

basis_tests=0
for f in tests/basis/*.sml; do
  case "$(basename "$f")" in harness.sml|finish.sml) continue ;; esac
  basis_tests=$((basis_tests + 1))
  id=basis.$(basename "$f" .sml | sed 's/_.*//')
  if ! echo "$rows" | grep -qx "$id"; then
    fail "test $f has no row '$id' in $doc"
  elif ! echo "$tested" | grep -qx "$id"; then
    fail "test $f exists but '$id' is not marked Supported or Partial in $doc"
  fi
done

# 3. opcodes and primitives are documented
for op in $(grep -v '^[[:space:]]*#' vm/opcodes.def | awk 'NF { print $1 }'); do
  grep -q "\`$op[ \`]" docs/bytecode.md || fail "opcode $op (vm/opcodes.def) is not documented in docs/bytecode.md"
done
for p in $(grep -v '^[[:space:]]*#' vm/prims.def | awk 'NF { print $1 }'); do
  grep -qE "(\`| )$p(\`| )" docs/bytecode.md || fail "primitive $p (vm/prims.def) is not documented in docs/bytecode.md"
done

# 4. basis structures are documented
for f in lib/basis/*.sml; do
  for s in $(grep -E '^structure [A-Za-z0-9_]+' "$f" | awk '{ print $2 }'); do
    grep -q "\`$s[\`.:]" "$doc" || fail "structure $s ($f) is not mentioned in $doc"
  done
done

# 5. manifest consistency
for f in $(grep -v '^[[:space:]]*#' lib/basis/MANIFEST | grep -v '^[[:space:]]*$'); do
  [ -f "lib/basis/$f" ] || fail "lib/basis/MANIFEST lists missing file $f"
done
for f in lib/basis/*.sml; do
  grep -qx "$(basename "$f")" lib/basis/MANIFEST || fail "$f is not listed in lib/basis/MANIFEST"
done

# 6. every test has an expected output
for f in tests/lang/*.sml; do
  [ -f "${f%.sml}.expected" ] || fail "missing ${f%.sml}.expected"
done
for f in tests/errors/*.sml; do
  [ -f "${f%.sml}.expected" ] || fail "missing ${f%.sml}.expected"
done

if [ $status = 0 ]; then
  echo "check-docs: OK ($(echo "$tested" | wc -l | tr -d ' ') documented features, $(ls tests/lang/*.sml | wc -l | tr -d ' ') tests, $basis_tests Basis Library suite files)"
fi
exit $status
