-- Report 4.4.1: a type variable scopes over its signature alone: the a of x :: a is another.
module Main (main) where

f :: a -> a
f x = x :: a

main :: IO ()
main = return ()
