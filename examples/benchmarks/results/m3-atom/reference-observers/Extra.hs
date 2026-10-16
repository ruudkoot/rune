module Main where
import Kernel
import GHC.Float(castFloatToWord32)
import Numeric(showHex)
import System.Environment
badLaw _ stream=map (const(error "force demanded")) stream
main=do
 [mode]<-getArgs
 case mode of
  "two"->putStr(show(take 2(runExperiment badLaw 0.02 [1.0] (State[1.0][0.0]))))
  "three"->putStr(show(take 3(runExperiment badLaw 0.02 [1.0] (State[1.0][0.0]))))
  "multi"->do
    let force=head(testforce[1.0,3.0][State[1.0,2.0][0.0,0.0]])
    let State p v=propagate 0.02 force(State[1.0,2.0][0.0,0.0])
    print(map(\x->showHex(castFloatToWord32 x)"")force)
    print(map(\x->showHex(castFloatToWord32 x)"")p)
    print(map(\x->showHex(castFloatToWord32 x)"")v)
