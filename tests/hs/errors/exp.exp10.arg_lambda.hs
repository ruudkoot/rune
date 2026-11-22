-- Report 3: a lambda is an exp10, no aexp, so no unparenthesised argument: f \x -> x.
module Main (main) where

f :: (Int -> Int) -> Int
f g = g 1

x :: Int
x = f \y -> y

main :: IO ()
main = return ()
