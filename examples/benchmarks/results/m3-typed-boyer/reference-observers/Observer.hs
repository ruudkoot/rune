module Main where
import Kernel
import System.Environment
sex(Var i)="?"++show i
sex(Fun f args _)="("++show f++concatMap((" "++).sex)args++")"
collect seen []=[]
collect seen (Var _:rest)=collect seen rest
collect seen (Fun f args rules:rest)
 | f`elem`seen=collect seen(args++rest)
 | otherwise=(show f,[(sex a,sex b)|(a,b)<-rules]):collect(f:seen)(args++concatMap(\(a,b)->[a,b])rules++rest)
main=do
 let(term,reps)=termDefs(Var X)
 print(collect[]reps)
 putStrLn(sex term)
 putStrLn(sex(rewrite term))
 print(tautp term)
