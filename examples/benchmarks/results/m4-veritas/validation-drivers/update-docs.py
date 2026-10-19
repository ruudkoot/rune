from pathlib import Path
import json
root=Path.cwd();suite=root/'examples/benchmarks';out=suite/'results/m4-veritas'
s=json.loads((out/'summary.json').read_text())
p=root/'docs/plans/benchmarks.md';text=p.read_text()
text=text.replace('M4 is in progress; M5, M6 and M7 are complete with recorded evidence; M8 remains planned. Source inventory entries are scheduled work, not passing ports.',
 'M4, M5, M6 and M7 are complete with recorded evidence; M8 coverage closure is in progress. Dispositions distinguish suitable imports from deferred/excluded sources.')
text=text.replace('Sandmark collection. M3 kernels are complete; M4 applications remain in progress; M8\ncoverage closure remains planned.',
 'Sandmark collection. M3 kernels and M4 applications are complete; M8\ncoverage closure is in progress.')
old='Veritas now registers lazy and strict ports after independent request-stream\nand editor-outcome agreement and private 400-repeat smoke checks. Its public\nhost/profile, count and acceptance gates remain pending; M4 is still in progress.'
new=f"""Veritas closes M4 with [recorded validation](../../examples/benchmarks/results/m4-veritas/README.md):
{s['profile_pass']} of 56 profile combinations pass, including all 32 Rune combinations.
Thirteen complete semantic groups each pass 218 assertions, eight normal
allocation samples agree, and full repository acceptance passes. All 34
suitable nofib real application paths now have implemented profiles;
source-loading/compile deadlines remain recorded host failures."""
assert old in text;text=text.replace(old,new)
text=text.replace('| **M4 — nofib applications** | In progress |','| **M4 — nofib applications** | Complete |')
text=text.replace('| **M8 — Coverage closure and maintenance** | Planned |','| **M8 — Coverage closure and maintenance** | In progress |')
text=text.replace('This does not mark M4 or M8 complete. M3 closure is recorded in the',
 'M4 completion is recorded in the [Veritas closure evidence](../../examples/benchmarks/results/m4-veritas/README.md).\nM8 remains in progress. M3 closure is recorded in the')
p.write_text(text)
p=suite/'README.md';text=p.read_text().replace('M4 applications and M8 coverage closure remain unfinished.',
 'M4 application coverage is [complete with recorded host exceptions](results/m4-veritas/README.md);\nM8 coverage closure is in progress.')
p.write_text(text)
p=suite/'README.md';text=p.read_text()
assert text.count('Public host/profile validation is pending.')==2
text=text.replace('Public host/profile validation is pending.',
 'Public validation is [recorded](results/m4-veritas/README.md), including host deadlines and incomplete attempts.')
p.write_text(text)
for variant in ['veritas-lazy','veritas-strict']:
 p=suite/variant/'PROVENANCE.md';text=p.read_text()
 text=text.replace('literature. Private source comparisons and both 400-repeat smoke drivers pass.\nPublic host/profile, count and repository acceptance gates are pending.',
 'literature. [Public validation](../results/m4-veritas/README.md) records all 32\nRune smoke/normal combinations passing, thirteen complete 218-check semantic\ngroups, agreeing normal allocation counts and full repository acceptance.\nHost deadlines and incomplete attempts remain explicit; broader large-host\nsweeps are unrecorded.')
 p.write_text(text)
p=suite/'validation.md';text=p.read_text()
assert '## M4 closure: Veritas'not in text
text+=f"""
## M4 closure: Veritas, 2026-10-19

The lazy and strict Veritas ports complete all 34 suitable pinned nofib real
application paths. The catalogue contains 507 programs and 1473 profiles.
[The complete evidence](results/m4-veritas/README.md) retains {s['profile_pass']} passing
profile combinations out of 56, including all 32 Rune combinations at O0/O2
across four engines. Nonpassing host compiles/source loads retain their
actual deadline and phase status; no incorrect or incomplete run contributes
an accepted timing.

Original GHC observations establish the complete 1391-byte request stream,
all 400/4000/20000 repeated hashes, lexical/parser outputs and 25 proof-editor
outcomes. Thirteen canonical semantic groups each pass 218 assertions;
ML Kit reaches its 600-second compile deadline. Ten earlier incomplete
fixture-transport groups and all corrected retries remain in the 24-group
attempt ledger. Both policies preserve the source's partial/stubbed behavior.

All eight normal allocation comparisons agree under the unchanged guards.
Final serial adapter checks retain two accepted Poly/ML fresh samples
and four rejected MLton/legacy SML/NJ compile deadlines. Earlier parser-pair and
development-port failures remain separately identifiable. The full
make JOBS=4 check passes after {s['acceptance']['elapsed_seconds']:.1f} seconds on the recorded
combined Veritas/closure working-tree subject. M4 is complete; M8's report,
maintenance and final retention audit are still in progress.
"""
p.write_text(text)
