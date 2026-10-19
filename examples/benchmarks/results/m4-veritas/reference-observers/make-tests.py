from pathlib import Path
import re,shutil,csv,subprocess
root=Path.cwd();p=Path(__file__).resolve().parent;data=root/'tests/benchmarks/data/nofib-veritas';data.mkdir(exist_ok=True)
def copy(src,dest):
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
for f in p.glob('protocol-*.reference'):copy(f,data/f.name)
for f in p.glob('parse-*.reference'):copy(f,data/f.name)
for f in p.glob('tokens-*.reference'):copy(f,data/f.name)
copy(p/'parser-inputs.tsv',data/'parser-inputs.tsv')
copy(p/'source/veritas.stdin',data/'source/veritas.stdin')
for name in(p/'cases/FILES').read_text().splitlines():
 for ext in ['input','protocol','proof']:copy(p/'cases'/(name+'.'+ext),data/'cases'/(name+'.'+ext))
copy(p/'cases/FILES',data/'cases/FILES')
(data/'.gitattributes').write_text('# Exact byte input and original ASCII-hex observations.\n** -whitespace\n')
code=r'''(* Independent observations of pinned Veritas source behavior.
   Protocol, parser and editor results are separate correctness claims. *)
functor NofibVeritasTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNofibVeritasFn(D)
 structure L=BenchLazy
 val root="tests/benchmarks/data/nofib-veritas/"
 fun read path=BenchApplicationTestIO.read path
'''
def body(name):
 source=(p/name).read_text()
 start=source.index(' val root=')
 end=source.index('\nend\nstructure Need=')
 result=source[start:end]
 result=re.sub(r' val root="[^\n]+"\n','',result,count=1)
 result=re.sub(r' fun read path=.*\n','',result,count=1)
 return result
protocol=body('protocol-probe.sml')
a=protocol.index(' fun check name actual=');b=protocol.index(' fun outputs',a)
protocol=protocol[:a]+''' fun check name actual=BenchApplicationTestIO.compare("nofib-veritas/"^label^"/protocol/"^name,
     read(root^"protocol-"^name^".reference"),actual)
'''+protocol[b:]
code+='\n structure Protocol=struct\n'+protocol+'\n end\n'
parsing=body('parse-probe.sml')
a=parsing.index(' fun check name actual=');b=parsing.index(' fun tokens',a)
parsing=parsing[:a]+''' fun check name actual=BenchApplicationTestIO.compare("nofib-veritas/"^label^"/"^name,
     read(root^name^".reference"),actual)
'''+parsing[b:]
code+='\n structure Parsing=struct\n'+parsing+'\n end\n'
cases=body('cases-probe.sml')
a=cases.index(' fun check name phase expected actual=');b=cases.index(' fun one name=',a)
cases=cases[:a]+''' fun check name phase expected actual=BenchApplicationTestIO.compare(
     "nofib-veritas/"^label^"/"^name^"/"^phase,expected,actual)
'''+cases[b:]
# Every original observation is required, including explicit Bad outcomes.
cases=cases.replace('else print("INCOMPLETE original proof "^name^"\\n")','else raise Fail("missing original outcome "^name)')
cases=cases.replace('else print("INCOMPLETE original protocol "^name^"\\n")','else raise Fail("missing original protocol "^name)')
code+='\n structure Editor=struct\n'+cases+'\n end\n'
code+=r'''
 val input=root^"source/veritas.stdin"
 val _=T.check("nofib-veritas/"^label^"/complete-program-hash",fn()=>
     K.benchmark(K.input(read input))=valOf(Word64.fromString"0wxCD1FC6B0A4675CFB"))
 val _=T.check("nofib-veritas/"^label^"/signed-program-hash",fn()=>
     K.signedHash(valOf(Word64.fromString"0wxCD1FC6B0A4675CFB"))="-3665993109681513221")
 structure Check=BenchNofibVeritasCheckFn(K)
 val _=T.check("nofib-veritas/"^label^"/zero-skips-input",fn()=>Check.run["0","missing-source","0"]="0")
 val _=T.check("nofib-veritas/"^label^"/negative-skips-input",fn()=>Check.run["-2","missing-source","0"]="0")
 val _=T.check("nofib-veritas/"^label^"/wrong-result-rejected",fn()=>
      ((Check.run["1",input,"0"];false)handle Fail message=>String.isPrefix"incorrect result: "message|_=>false))
end
structure NeedVeritas=NofibVeritasTestsFn(structure D=BenchNeed val label="lazy")
structure StrictVeritas=NofibVeritasTestsFn(structure D=BenchStrict val label="strict")
'''
(root/'tests/benchmarks/nofib-veritas-tests.sml').write_text(code)
files=sorted(str(f.relative_to(root))for f in data.rglob('*')if f.is_file()and f!=data/'FILES')
(data/'FILES').write_text('\n'.join(files)+'\n')
f=root/'tests/benchmarks/check-nofib-applications.sh'
f.write_text(f.read_text().replace('parser|reptile|hpg|fluid|anna)','parser|reptile|hpg|fluid|anna|veritas)'))
(root/'tests/benchmarks/check-nofib-veritas.sh').write_text('#!/bin/sh\nset -eu\nexec sh "$(dirname "$0")/check-nofib-applications.sh" veritas\n')
rows=list(csv.DictReader((root/'examples/benchmarks/manifest.tsv').open(),delimiter='\t'))
row=next(row for row in rows if row['benchmark']=='veritas-lazy'and row['profile']=='smoke')
files=['tests/basis/harness.sml','tests/benchmarks/application-test-io.sml']+[
    'examples/benchmarks/'+s for s in row['sources'].split(',')if s not in ['veritas-lazy/benchmark.sml','shared/main.sml']]
files+=['tests/benchmarks/nofib-veritas-tests.sml','tests/basis/finish.sml']
(p/'public-test-sources.txt').write_text('\n'.join(files)+'\n')
print('prepared Veritas semantic tests and independent data')
with(p/'public-semantic-build.log').open('w')as f:
 r=subprocess.run(['bin/rune','-O0',*files,'-o',str(p/'public-semantic.rbc')],stdout=f,stderr=subprocess.STDOUT)
raise SystemExit(r.returncode)
