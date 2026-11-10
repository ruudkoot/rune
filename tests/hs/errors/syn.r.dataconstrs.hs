-- Report 9.5: topdecl -> data [context =>] simpletype = constrs [deriving], constrs n >= 1: a data declaration has a
-- constructor (chapter 8 writes `data Float` without, as no program may).
module Main (main) where

data T

main :: IO ()
main = return ()
