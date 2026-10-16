module Main where
import Kernel
import GHC.Float(castFloatToWord32)
import Numeric(showHex)
import System.Environment
main=do
 [arg]<-getArgs
 mapM_ (\(State p v)->putStrLn(unwords(map(\x->showHex(castFloatToWord32 x)"")p)++" | "++unwords(map(\x->showHex(castFloatToWord32 x)"")v))) (take(read arg)test)
