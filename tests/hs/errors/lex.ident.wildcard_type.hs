-- Report 2.4: "_ all by itself is a reserved identifier, used as wild card in patterns": not a type variable.
module Main (main) where

f :: _ -> Int
f _ = 1

main :: IO ()
main = return ()
