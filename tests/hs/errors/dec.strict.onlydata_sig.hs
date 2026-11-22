-- Report 4.2.1: ! means strictness only in the argument types of a data declaration: not f :: !Int -> Int.
module Main (main) where

f :: !Int -> Int
f x = x

main :: IO ()
main = return ()
