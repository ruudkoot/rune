from pathlib import Path
import subprocess
p=Path(__file__).resolve().parent
parts=['geometry-prefix.sml','geometry-generated.sml','geometry-align.sml','database.sml','selectors.sml','relationships.sml','search.sml','domains.sml','consumer.sml']
(p/'search-kernel.sml').write_text(''.join((p/f).read_text()for f in parts)+'\nend\n')
(p/'search-probe.sml').write_text('''structure K=BenchNucleic2Fn(structure D=BenchNeed val shared=false)
val solutions=K.pseudoknot"1"
val result=BenchNeed.force(K.most_distant_atom solutions)
val _=print("MAXIMUM "^Real.toString result^"\\n")
val _=print("SOLUTIONS "^Int.toString(K.F.length solutions)^"\\n")
''')
with(p/'search-probe-build.log').open('w')as out:
 subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml','examples/benchmarks/shared/finite-binary32.sml',str(p/'search-kernel.sml'),str(p/'search-probe.sml'),'-o',str(p/'search-probe.rbc')],stdout=out,stderr=subprocess.STDOUT,check=True)
print('search probe compiled')
