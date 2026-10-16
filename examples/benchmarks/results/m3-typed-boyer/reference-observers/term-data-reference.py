from pathlib import Path
import subprocess,ast,json,re
r=Path(__file__).resolve().parent;source=(r/'Main.lhs').read_text().replace('module Main (main) where','module RichKernel where').replace('deriving Eq','deriving (Eq,Show)',1)
reps=['add1 a','and_ a b','append a b','cons a b','consp a','difference a b','divides a b','equal a b','even_ a','exp_ a b','f a','four','gcd_ a b','greatereqp a b','greaterp a b','if_ a b c','iff a b','implies a b','length_ a','lesseqp a b','lessp a b','listp a','member a b','nilp a','nlistp a','not_ a','odd_ a','one','or_ a b','plus a b','quotient a b','remainder a b','reverse_ a','sub1 a','times a b','two','zerop a','false','nil','true','zero']
old='test0 xxxx = tautp (apply_subst subst0 theorem)';new='test0 xxxx = let (term,_,_,_)=termDefs xxxx in tautp term\n\ntermDefs xxxx = (apply_subst subst0 theorem, ['+', '.join(reps)+'], theorem, subst0)';assert old in source;(r/'RichKernel.lhs').write_text(source.replace(old,new))
(r/'DataObserver.hs').write_text('''module Main where
import RichKernel
sex(Var i)="?"++show i
sex(Fun f args _)="("++show f++concatMap((" "++).sex)args++")"
pairTerms(a,b)=[a,b]
collect seen []=[]
collect seen (Var _:rest)=collect seen rest
collect seen (Fun f args rules:rest)
 | f`elem`seen=collect seen(args++rest)
 | otherwise=(show f,[(sex a,sex b)|(a,b)<-rules]):collect(f:seen)(args++concatMap pairTerms rules++rest)
main=do
 let(term,reps,theorem,bindings)=termDefs(Var A)
 print(collect[]reps)
 putStrLn(sex theorem)
 print[(show ident,sex value)|(ident,value)<-bindings]
''')
with(r/'data-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','data-observer','DataObserver.hs'],cwd=r,stdout=log,stderr=subprocess.STDOUT,check=True)
raw=subprocess.check_output([str(r/'data-observer')],text=True,timeout=180);(r/'data-observer.output').write_text(raw);lines=raw.splitlines();data=dict(rules=ast.literal_eval(lines[0]),template=lines[1],substitution=ast.literal_eval(lines[2]));assert len(data['rules'])==41
(r/'term-data.json').write_text(json.dumps(data,indent=2)+'\n');print('PASS original graph export:41function IDs, uninstantiated theorem and5substitution terms')
