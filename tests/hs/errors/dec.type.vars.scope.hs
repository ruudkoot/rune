-- Report 4.2.2: no other type variable stands on the right of a synonym.
module Main (main) where

type T a = b

main :: IO ()
main = return ()
