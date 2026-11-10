-- Report 4.2.1: no other type variable stands in the context.
module Main (main) where

data Eq b => T a = C a

main :: IO ()
main = return ()
