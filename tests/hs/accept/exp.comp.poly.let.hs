-- Report 3.11: a let in a comprehension is polymorphic.
module Main (main) where

p :: [(Int, Char)]
p = [(f 1, f 'a') | let f x = x]

main :: IO ()
main = return ()
