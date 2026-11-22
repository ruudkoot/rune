-- Report 4.2.1: no other type variable stands on the right.
module Main (main) where

data T a = C b

main :: IO ()
main = return ()
