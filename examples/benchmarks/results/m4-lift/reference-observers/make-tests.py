from pathlib import Path
import shutil,subprocess
root=Path.cwd();p=Path(__file__).resolve().parent
data=p/'data';data.mkdir(exist_ok=True)
for f in [*p.glob('case-*.json'),*p.glob('*.reference')]:shutil.copy(f,data/f.name)
(data/'wrong.report').write_text('deliberately incorrect\n')
t=(p/'case-pilot.sml').read_text().replace('structure LiftCases','structure LiftTests').replace('if actual^"\\n"=read path then print("PASS "^key^"\\n")else raise Fail key','T.check("lift/"^key,fn()=>actual^"\\n"=read path)')
t=t[:t.rindex('end')]
t+=r'''
 structure NP=BenchLiftPrintFn(N)
 structure EP=BenchLiftPrintFn(E)
 structure NC=BenchLiftCheckFn(N)
 structure EC=BenchLiftCheckFn(E)
 structure L=BenchLazy
 exception Demanded
 fun demanded Demanded=true|demanded _=false
 val touches=ref 0
 val deferred:N.name N.expr=L.delay(fn()=>(touches:= !touches+1;N.EConst(N.CNum 42)))
 val _=T.check("lift/need-boundary-defers",fn()=>
   (ignore(N.boundaryExpr N.forceName deferred); !touches=0))
 val _=T.check("lift/shared-node-forced-once",fn()=>
   (ignore(L.force deferred);ignore(L.force deferred); !touches=1))
 val strictTouches=ref 0
 val strictNode:E.name E.expr=L.delay(fn()=>(strictTouches:= !strictTouches+1;E.EConst(E.CNum 42)))
 val _=T.check("lift/strict-boundary-demands",fn()=>
   (ignore(E.boundaryExpr E.forceName strictNode); !strictTouches=1))
 val _=T.raises("lift/strict-boundary-poison",demanded,fn()=>
   E.boundaryExpr E.forceName(L.delay(fn()=>raise Demanded)))
 val _=T.check("lift/need-variable-tag-shared",fn()=>
   let val hits=ref 0 val nm=L.delay(fn()=>(hits:= !hits+1;"x"))
       val fv=N.freeVars(N.var nm)
       val first=N.tag fv val second=N.tag fv
   in !hits=0 andalso List.map L.force first=["x"]andalso
      List.map L.force second=["x"]andalso !hits=1 end)
 val _=T.check("lift/free-vars-sorted-deduplicated",fn()=>
   List.map L.force(N.tag(N.freeVars(N.app(N.app(N.variable"z")(N.variable"a"))(N.variable"z"))))=["a","z"])
 val _=T.check("lift/recursive-let-binds-rhs",fn()=>
   List.null(N.tag(N.freeVars(N.lett true[(N.named"x",N.variable"x")](N.variable"x")))))
 val _=T.check("lift/nonrecursive-let-retains-rhs-free",fn()=>
   List.map L.force(N.tag(N.freeVars(N.lett false[(N.named"x",N.variable"x")](N.variable"x"))))=["x"])
 val _=T.check("lift/rec-renaming-knot",fn()=>
   let val info=L.delay(fn()=>0)
       val ast=L.delay(fn()=>N.ELet(true,[((N.named"x",info),N.variable"x")],N.variable"x"))
       val output=N.rename ast
   in case L.force output of N.ELet(true,[((name,_),rhs)],body)=>
        L.force name="x0"andalso
        (case L.force rhs of N.EVar n=>L.force n="x0"|_=>false)andalso
        (case L.force body of N.EVar n=>L.force n="x0"|_=>false)
      |_=>false end)
 val _=T.check("lift/source-lambda-supply-quirk",fn()=>
   let val z=L.delay(fn()=>0)
       val ast=L.delay(fn()=>N.EAp(N.lam[(N.named"x",z)](N.lam[(N.named"y",z)](N.variable"x")),
         N.lam[(N.named"z",z)](N.variable"z")))
   in case L.force(N.rename ast)of N.EAp(a,b)=>
       (case(L.force a,L.force b)of(N.ELam([(x,_)],inside),N.ELam([(z,_)],_))=>
         L.force x="x0"andalso L.force z="z1"andalso
         (case L.force inside of N.ELam([(y,_)],_)=>L.force y="y1"|_=>false)
       |_=>false)|_=>false end)
 val _=T.check("lift/arbitrary-precision-constant",fn()=>
   let val n=valOf(IntInf.fromString"123456789012345678901234567890")
   in NP.expression(N.cn n)="123456789012345678901234567890"andalso
      EP.expression(E.cn n)="123456789012345678901234567890"end)
 val _=T.check("lift/pretty-negative",fn()=>NP.expression(N.cn ~42)="~42"orelse NP.expression(N.cn ~42)="-42")
 val _=T.check("lift/printer-pending-indent",fn()=>
   NP.mkstr(NP.concat[NP.text"a\n",NP.indent 4(NP.text"b\nc"),NP.text"\nd"])="a\n    b\n    c\nd")
 val _=T.check("lift/printer-delayed-expression",fn()=>
   let val hits=ref 0 val expr=L.delay(fn()=>(hits:= !hits+1;N.EConst(N.CNum 1)))
       val sequence=NP.ppr NP.name expr
   in !hits=0 andalso NP.mkstr sequence="1"andalso !hits=1 end)
 val _=T.check("lift/complete-report-need",fn()=>NC.report(N.program())=read"report.reference")
 val _=T.check("lift/complete-report-strict",fn()=>EC.report(E.program())=read"report.reference")
 val wantedHash=String.substring(read"hash.reference",0,16)
 val _=T.check("lift/Word64-source-hash",fn()=>Word64.fmt StringCvt.HEX(NC.hash(read"report.reference"))="8A2CD0A394A3204D")
 val _=T.check("lift/zero-repetitions",fn()=>NC.run["0","report.reference",wantedHash]="0:0")
 val _=T.check("lift/smoke-both-transforms-need",fn()=>NC.run["1","report.reference",wantedHash]="1:1948")
 val _=T.check("lift/smoke-both-transforms-strict",fn()=>EC.run["1","report.reference",wantedHash]="1:1948")
 val _=T.raises("lift/reject-incorrect-report",fn Fail _=>true|_=>false,fn()=>NC.run["1","wrong.report",wantedHash])
 val _=T.raises("lift/reject-incorrect-hash",fn Fail _=>true|_=>false,fn()=>EC.run["1","report.reference","0"])
end
'''
# Do not permit a different negative spelling through the oracle.
t=t.replace('NP.expression(N.cn ~42)="~42"orelse NP.expression(N.cn ~42)="-42"','NP.expression(N.cn ~42)="-42"')
(p/'tests.sml').write_text(t)
sources=[root/'tests/basis/harness.sml',root/'examples/benchmarks/shared/lazy.sml',root/'examples/benchmarks/shared/input.sml']+[p/x for x in ['kernel.sml','print.sml','check.sml','serialize.sml','tests.sml']]+[root/'tests/basis/finish.sml']
(p/'sources.txt').write_text(''.join(str(x)+'\n'for x in sources))
(p/'data-list').write_text(''.join(x.name+'\n'for x in sorted(data.iterdir())))
with(p/'tests-build.log').open('w')as log:subprocess.run([str(root/'bin/rune'),'--lint',*map(str,sources),'-o',str(p/'tests.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'tests.log').open('w')as log:subprocess.run([str(root/'bin/runevm'),str(p/'tests.rbc')],cwd=data,stdout=log,stderr=subprocess.STDOUT,check=True)
print((p/'tests.log').read_text().splitlines()[-1])
