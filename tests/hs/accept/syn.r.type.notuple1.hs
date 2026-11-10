-- Report 9.5: atype -> ( type ) is a parenthesised type, and tuple types have k >= 2: (Int) is Int.
module Main (main) where

f :: (Int) -> ((Int))
f x = x

main :: IO ()
main = print (f 1)
