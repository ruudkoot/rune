-- Report 4.2.2: a synonym is not partially applied: not P bare as an argument.
module Main (main) where

type P a b = (a, b)
data App f = A (f Int Int)

x :: App P
x = undefined

main :: IO ()
main = return ()
