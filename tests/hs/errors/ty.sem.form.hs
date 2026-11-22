-- Report 4.1.4: in forall u. cx => t a variable of cx is free in t: Show a => Int is ambiguous.
module Main (main) where

f :: Show a => Int
f = 1

main :: IO ()
main = return ()
