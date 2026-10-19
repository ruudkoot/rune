from pathlib import Path
import csv,hashlib,json,re,shutil
root=Path.cwd();p=Path(__file__).resolve().parent;suite=root/'examples/benchmarks';dest=suite/'results/m8-closure'
scope={'__file__':str(p/'curate.py')};exec((root/'tests/out/benchmarks/m4-anna/curate.py').read_text().split("assert json.loads((p/'acceptance-exit.json')")[0],scope)
copy=scope['copy'];tree=scope['tree'];table=scope['table']
assert json.loads((p/'acceptance-exit.json').read_text())['exit']==0
dest.mkdir(exist_ok=True);(dest/'.gitattributes').write_text('# Exact metadata, archived fixtures and execution evidence.\n** -whitespace\n')
for f in sorted(p.iterdir()):
 if f.is_file()and f.suffix!='.rbc'and not f.name.startswith('archive-retain-paths'):copy(f,dest/'validation-drivers'/f.name)
for name in ['m8-inventory-tests.log','m8-inventory-replay.log','m8-multiline-main.json']:
 copy(root/'tests/out/benchmarks'/name,dest/name)
for name in ['coverage-tests.PG5leH','coverage-tests.yyKJGO','provenance-tests.Jq5Yow']:
 tree(root/'tests/out/benchmarks'/name,dest/'regressions'/name)
for f in ['coverage.sml','coverage-main.sml']:
 copy(suite/'shared'/f,dest/'tool-sources'/f)
for f in ['benchmark-provenance.sh','measure-benchmarks.sh','benchmark-inventory.py']:
 copy(root/'scripts'/f,dest/'tool-sources'/f)
for f in ['check-coverage.sh','coverage.sml','check-provenance.sh','test-inventory.py']:
 copy(root/'tests/benchmarks'/f,dest/'tool-sources'/f)
for name in ['coverage.tsv','inventory.tsv','source-variants.tsv','upstreams.tsv']:
 copy(suite/name,dest/name)
copy(p/'evidence-index.tsv',dest/'evidence-index.tsv')
copy(p/'runtime-files.tsv',dest/'runtime-files.tsv')
copy(p/'archive-text-identities.tsv',dest/'retained-text-identities.tsv')
copy(p/'archive-exclusions.tsv',dest/'excluded-binary-identities.tsv')
copy(p/'archive-aliases.tsv',dest/'text-state-aliases.tsv')
# Regression measurements preserve their own source/subject epochs.
for log in [p/'measurement-regressions-final.log']:
 if log.exists():
  for value in re.findall(r'^BENCH MEASUREMENT (.+)$',log.read_text(),re.M):
   run=Path(value);tree(run,dest/'measurement-regressions'/run.name)
table(dest/'excluded-payloads.tsv',['original_path','bytes','sha256'],sorted(set(scope['skipped'])))
for row in csv.DictReader((dest/'evidence-index.tsv').open(),delimiter='\t'):
 assert(suite/row['primary_evidence']).is_file(),row
print('M8 evidence curated; all 507 primary links exist')
