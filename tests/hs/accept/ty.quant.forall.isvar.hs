-- rows: R66
-- Report 4.1.2: forall is no reserved word, so in a type it is a type variable.
module Main (main) where

f :: forall -> forall
f x = x

main :: IO ()
main = return ()
