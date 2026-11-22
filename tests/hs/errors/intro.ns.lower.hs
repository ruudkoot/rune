-- Report 1.4: a type variable is lower-case: an upper-case one is a type constructor, unbound here.
module Main (main) where

f :: A -> A
f x = x

main :: IO ()
main = return ()
