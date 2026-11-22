-- rows: R23
-- Report 4.2.1: topdecl -> data [context =>] simpletype = constrs, constrs n >= 1: not data T (R23; chapter 8's
-- own data Float is no Haskell 98).
module Main (main) where

data T

main :: IO ()
main = return ()
