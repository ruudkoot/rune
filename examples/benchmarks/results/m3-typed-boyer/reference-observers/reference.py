from pathlib import Path
import subprocess,resource,ast,json
r=Path(__file__).resolve().parent
source=(r/'Main.lhs').read_text().replace('module Main (main) where','module Kernel where').replace('deriving Eq','deriving (Eq,Show)',1)
reps=['add1 a','and_ a b','append a b','cons a b','consp a','difference a b','divides a b','equal a b','even_ a','exp_ a b','f a','four','gcd_ a b','greatereqp a b','greaterp a b','if_ a b c','iff a b','implies a b','length_ a','lesseqp a b','lessp a b','listp a','member a b','nilp a','nlistp a','not_ a','odd_ a','one','or_ a b','plus a b','quotient a b','remainder a b','reverse_ a','sub1 a','times a b','two','zerop a','false','nil','true','zero']
old='test0 xxxx = tautp (apply_subst subst0 theorem)';new='test0 xxxx = tautp (fst (termDefs xxxx))\n\ntermDefs xxxx = (apply_subst subst0 theorem, ['+', '.join(reps)+'])';assert old in source;source=source.replace(old,new)
(r/'Kernel.lhs').write_text(source)
(r/'Observer.hs').write_text(r'''module Main where
import Kernel
import System.Environment
sex(Var i)="?"++show i
sex(Fun f args _)="("++show f++concatMap((" "++).sex)args++")"
pairTerms(a,b)=[a,b]
collect seen []=[]
collect seen (Var _:rest)=collect seen rest
collect seen (Fun f args rules:rest)
 | f`elem`seen=collect seen(args++rest)
 | otherwise=(show f,[(sex a,sex b)|(a,b)<-rules]):collect(f:seen)(args++concatMap pairTerms rules++rest)
main=do
 let(term,reps)=termDefs(Var X)
 print(collect[]reps)
 putStrLn(sex term)
 putStrLn(sex(rewrite term))
 print(tautp term)
''')
# Raw string supplies literal lambda syntax in the observer.
p=r/'Observer.hs';p.write_text(p.read_text().replace('\\\\(a,b)','\\(a,b)'))
for source,exe in [('Main.lhs','original'),('Observer.hs','observer')]:
 with(r/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,source],cwd=r,stdout=log,stderr=subprocess.STDOUT,check=True)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(300,300))
for label,n in [('fast',2),('normal',15),('large',75)]:
 raw=subprocess.check_output([str(r/'original'),str(n)],timeout=315,preexec_fn=bounded);fixture=r/('boyer.'+('faststdout'if label=='fast'else'slowstdout'if label=='large'else'stdout'));assert raw==fixture.read_bytes()==b'True\n'*100;print('PASS complete original output',label,n,flush=True)
raw=subprocess.check_output([str(r/'observer')],text=True,timeout=315,preexec_fn=bounded);(r/'observer.output').write_text(raw);lines=raw.splitlines();rules=ast.literal_eval(lines[0]);(r/'rules.json').write_text(json.dumps(rules,indent=2)+'\n');(r/'input.term').write_text(lines[1]+'\n');(r/'normal.term').write_text(lines[2]+'\n');assert lines[3]=='True';print('Original embedded-rule graph:',len(rules),'function IDs;',len(lines[2]),'normal-form bytes',flush=True)
