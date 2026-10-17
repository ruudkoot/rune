module Main where
import qualified Event as E
import System.Environment
showState E.C_X='x'
showState E.C_L='L'
showState E.C_H='H'
main = do
 [mode,arg] <- getArgs
 let n=read arg
 if mode=="state" then putStr(E.f_benchmark_main n)
 else if mode=="deps" then mapM_ (putStrLn . unwords . map show . E.f_dependencies)[0..12]
 else mapM_ (\(E.F_At t w s)->putStrLn(unwords[show t,show w,[showState s]])) (E.f_simulate E.c_ievents E.c_istate n)
