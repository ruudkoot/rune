from pathlib import Path
import subprocess,json,ast
p=Path(__file__).resolve().parent
base=(p/'database-probe.sml').read_text()
helpers=base[base.index(' structure W='):base.index(' fun matrix')]
test=r'''functor SolutionsProbeFn(structure D:BENCH_SUSPEND val shared:bool val label:string)=struct
 structure K=BenchNucleic2Fn(structure D=D val shared=shared)
HELPERS
 fun sequence emit values=
  let fun loop values=case D.force values of K.F.Nil=>[]
        |K.F.Cons(value,rest)=>emit value::loop rest
  in array(loop values)end
 fun variable value=let val K.Var(i,_,n)=D.force value
   in array[Int.toString i,sequence(fn p=>array(point(K.absolute_pos value p)))(K.list_of_atoms n)]end
 val solutions=K.pseudoknot"1"
 val count=K.F.length solutions
 val result=D.force(K.most_distant_atom solutions)
 val output=TextIO.openOut("tests/out/benchmarks/nucleic2-originals/solutions-"^label^".actual")
 fun loop values=case D.force values of K.F.Nil=>()
   |K.F.Cons(solution,rest)=>(TextIO.output(output,sequence variable solution^"\n");loop rest)
 val _=loop solutions
 val _=TextIO.closeOut output
 val _=print(label^" "^Int.toString count^" "^Real.toString result^" "^bits result^"\n")
end
structure NeedDemand=SolutionsProbeFn(structure D=BenchNeed val shared=false val label="on-demand-need")
structure StrictDemand=SolutionsProbeFn(structure D=BenchStrict val shared=false val label="on-demand-strict")
structure NeedShared=SolutionsProbeFn(structure D=BenchNeed val shared=true val label="shared-need")
structure StrictShared=SolutionsProbeFn(structure D=BenchStrict val shared=true val label="shared-strict")
'''
test=test.replace('HELPERS',helpers)
(p/'solutions-probe.sml').write_text(test)
with(p/'solutions-probe-build.log').open('w')as out:
 subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml','examples/benchmarks/shared/finite-binary32.sml',str(p/'search-kernel.sml'),str(p/'solutions-probe.sml'),'-o',str(p/'solutions-probe.rbc')],stdout=out,stderr=subprocess.STDOUT,check=True)
print('all four full-solution observers compiled')
