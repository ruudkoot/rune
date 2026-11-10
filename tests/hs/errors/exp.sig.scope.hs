-- Report 3.16: a type variable of a signature scopes over that signature alone.
module Main (main) where

f :: b -> b
f = \x -> (x :: a)

main :: IO ()
main = return ()
