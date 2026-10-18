module Main where
import LambdaLift
import Print
import Test
import Utilities
import System.Environment
import Data.List(intercalate)
sml(EConst(CNum n))="cn ("++show n++")"
sml(EConst(CBool b))="cb "++(if b then"true"else"false")
sml(EConst(CFun n))="cf "++show n
sml(EVar n)="variable "++show n
sml(EAp a b)="app ("++sml a++") ("++sml b++")"
sml(ELam args body)="lam ["++intercalate ","(map(\n->"named "++show n)args)++"] ("++sml body++")"
sml(ELet rec defs body)="lett "++(if rec then"true"else"false")++" ["++intercalate ","(map(\(n,r)->"(named "++show n++","++sml r++")")defs)++"] ("++sml body++")"
main=do
 args<-getArgs
 case args of
  ["input-sml"]->putStrLn("fun program()= "++sml program)
  ["input"]->putStr(pprintExpr program)
  ["plain"]->putStr(pprintSCs(lambdaLift program))
  ["full"]->putStr(pprintSCs(fullyLazyLift program))
  ["report"]->putStr("\nInput expression "++pprintExpr program++"\nResult\n"++pprintSCs(lambdaLift program)++"\nFully lazy \n"++pprintSCs(fullyLazyLift program)++"\n")
  _->error"expected input-sml|input|plain|full|report"
