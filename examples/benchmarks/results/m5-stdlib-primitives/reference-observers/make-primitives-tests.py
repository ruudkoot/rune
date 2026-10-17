from pathlib import Path
import json,shutil
p=Path(__file__).resolve().parent;data=p/'primitive-data';data.mkdir(exist_ok=True);rows=json.loads((p/'primitives-reference.json').read_text())['profiles']
for row in rows:
 name=row['benchmark']+'-'+row['profile']+'.expected';shutil.copyfile(p/name,data/name)
cases=[]
for r in rows:
 args=[str(r['iterations'])]if r['length']is None else[str(r['length']),str(r['iterations'])]
 cases.append('  val _=T.check("stdlib/source/'+r['benchmark']+'/'+r['profile']+'",fn()=>K.'+('runArray'if r['length']is not None else'runComparison')+' "'+r['benchmark']+'"['+','.join('"'+s+'"'for s in args)+']=read "'+r['benchmark']+'-'+r['profile']+'.expected")')
s=r'''structure PrimitiveTests =
struct
  structure K=BenchStdlibPrimitives
  fun read path=let val f=TextIO.openIn path val line=valOf(TextIO.inputLine f)
    val _=TextIO.closeIn f in String.substring(line,0,String.size line-1)end
CASES
  val _=T.check("stdlib/array-empty-fold",fn()=>K.runArray "array_fold"["0","3"]="3:0:0:3:0")
  val _=T.check("stdlib/array-singleton-fold",fn()=>K.runArray "array_fold"["1","3"]="3:0:0:3:0")
  val _=T.check("stdlib/array-zero-repeats",fn()=>K.runArray "array_iter"["16","0"]="0:0:0:0:0")
  val _=T.check("stdlib/array-empty-forall",fn()=>K.runArray "array_forall"["0","3"]="3:0:0:3:0")
  val _=T.check("stdlib/array-iter-assertion",fn()=>
    ((K.arrayOperation "array_iter"(Array.fromList[1,999])1;false)handle Fail _=>true))
  val _=T.check("stdlib/array-forall-assertion",fn()=>
    ((K.arrayOperation "array_forall"(Array.fromList[1,999])1;false)handle Fail _=>true))
  val _=T.check("stdlib/array-forall-short-circuit",fn()=>
    let val visited=ref []
        val result=K.arrayForAll(fn n=>(visited:=n:: !visited;if n=999 then raise Fail "unused"else n<2))
          (Array.fromList[1,2,999])
    in not result andalso List.rev(!visited)=[1,2]end)
  val _=T.check("stdlib/array-invalid-initialization-rejected",fn()=>
    ((K.validateArray(Array.array(4,0));false)handle Fail _=>true))
  val _=T.check("stdlib/compare-list-prefix",fn()=>K.compareList([1],[1,2])= ~1 andalso K.compareList([1,2],[1])=1)
  val _=T.check("stdlib/compare-list-equal",fn()=>K.compareList([1,2],[1,2])=0)
  val _=T.check("stdlib/integer-pivot",fn()=>List.map(K.comparison "pervasives_compare_ints")[41,42,43]=[~1,0,1])
  val _=T.check("stdlib/float-pivot",fn()=>List.map(K.comparison "pervasives_compare_floats")[4,5,6]=[~1,0,1])
  val _=T.check("stdlib/immediate-int-equality",fn()=>List.map(K.comparison "pervasives_equal_ints")[41,42,43]=[0,1,0])
  val _=T.check("stdlib/modular-observer-wrap",fn()=>K.render(K.summarize 2(fn _=> ~1))="2:FFFFFFFE:2:0:0")
  val _=T.check("stdlib/invalid-length",fn()=>((K.runArray "array_fold"["10001","1"];false)handle Fail _=>true))
  val _=T.check("stdlib/invalid-count",fn()=>((K.runComparison "pervasives_compare_ints"["1000001"];false)handle Fail _=>true))
  val _=T.check("stdlib/negative-count",fn()=>((K.runComparison "pervasives_compare_ints"["~1"];false)handle Fail _=>true))
end
'''.replace('CASES','\n'.join(cases))
(p/'primitives-tests.sml').write_text(s)
root=Path.cwd();files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml',str(p/'primitives.sml'),str(p/'primitives-tests.sml'),'tests/basis/finish.sml']
(p/'primitive-sources.txt').write_text(''.join(str(root/f)+'\n'for f in files));(p/'primitive-data.txt').write_text(''.join(row['benchmark']+'-'+row['profile']+'.expected\n'for row in rows))
