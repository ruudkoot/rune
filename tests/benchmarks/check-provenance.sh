#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/provenance-tests.XXXXXX")
foreign=$out/compiler
mkdir -p "$foreign/bin" "$foreign/lib/basis" "$out/record" "$out/custom-record"
printf 'fixture compiler\n' > "$foreign/bin/rune"
printf 'fixture payload\n' > "$foreign/bin/rune.rbc"
printf '# fixture basis\n' > "$foreign/lib/basis/MANIFEST"
printf 'val basisFixture = 1\n' > "$foreign/lib/basis/fixture.sml"
git init --quiet "$foreign"
git -C "$foreign" add bin lib
git -C "$foreign" -c user.name='Benchmark Fixture' -c user.email='fixture@example.invalid' \
  -c commit.gpgsign=false commit --quiet -m 'Create compiler identity fixture'
revision=$(git -C "$foreign" rev-parse HEAD)
printf 'val basisFixture = 2\n' > "$foreign/lib/basis/fixture.sml"
. "$root/scripts/benchmark-provenance.sh"
bench_tool_repository compiler "$foreign/bin/rune" "$out/record"
grep -Fq "$(printf 'repository\t%s' "$foreign")" "$out/record/compiler-repository.tsv"
grep -Fq "$(printf 'revision\t%s' "$revision")" "$out/record/compiler-repository.tsv"
grep -Fq "$(printf 'dirty\t1')" "$out/record/compiler-repository.tsv"
grep -Fq "$foreign/bin/rune.rbc" "$out/record/compiler-payloads.sha256"
(cd "$foreign" && sha256sum lib/basis/MANIFEST lib/basis/*.sml) > "$out/expected-basis.sha256"
cmp "$out/expected-basis.sha256" "$out/record/basis.sha256"
custom=$(mktemp -d /tmp/rune-benchmark-provenance.XXXXXX)
trap 'rm -rf "$custom"' EXIT HUP INT TERM
printf 'custom launcher\n' > "$custom/rune"
bench_tool_repository compiler "$custom/rune" "$out/custom-record"
grep -Fq "$(printf 'repository\tunavailable')" "$out/custom-record/compiler-repository.tsv"
[ ! -s "$out/custom-record/compiler-payloads.sha256" ]
[ ! -f "$out/custom-record/basis.sha256" ]
echo "bench-provenance: foreign revision, dirty state, actual basis/payloads and unknown launchers remain distinct ($out)"
