from pathlib import Path
import csv,subprocess,json,time,sys
root=Path.cwd();p=root/'tests/out/benchmarks/m4-final-applications/legacy-types';p.mkdir(exist_ok=True)
manifest=list(csv.DictReader((root/'examples/benchmarks/manifest.tsv').open(),delimiter='\t'));records=[]
for family,functor in [('reptile','BenchReptileFn'),('hpg','BenchHpgFn'),('fluid','BenchFluidFn')]:
 if len(sys.argv)>1 and family not in sys.argv[1:]:continue
 row=next(r for r in manifest if r['benchmark']==family+'-lazy'and r['profile']=='smoke')
 sources=[root/'examples/benchmarks'/s for s in row['sources'].split(',')if not s.endswith(('/benchmark.sml','shared/main.sml'))]
 footer=p/(family+'-footer.sml');footer.write_text('structure Probe='+functor+'(BenchNeed)\nval _=print"PORTABLE TYPECHECK OK\\n"\nval _=OS.Process.exit OS.Process.success\n')
 driver=p/(family+'-driver.sml');driver.write_text('val _=('+ ';'.join('use '+json.dumps(str(s))for s in sources+[footer])+')handle e=>(print(General.exnMessage e^"\\n");OS.Process.exit OS.Process.failure)\n')
 cmd=['timeout','120','/home/ruud/.local/rune-hosts/smlnj-legacy/bin/sml',str(driver)]
 log=p/(family+'.log')
 with log.open('w')as out:r=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT)
 text=log.read_text();ok=r.returncode==0 and'PORTABLE TYPECHECK OK'in text and'Error:'not in text
 records.append(dict(family=family,exit=r.returncode,passed=ok,scope='frontend/module-instantiation probe, no benchmark result claim'))
 print(family,'PASS'if ok else'FAIL',flush=True)
(p/('outcomes-'+('-'.join(sys.argv[1:])if len(sys.argv)>1 else'all')+'.json')).write_text(json.dumps(records,indent=2)+'\n')
raise SystemExit(not all(r['passed']for r in records))
