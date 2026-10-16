module Main where
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
