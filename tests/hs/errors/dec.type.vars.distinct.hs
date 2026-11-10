-- Report 4.2.2: the variables of a synonym are distinct.
module Main (main) where

type T a a = a

main :: IO ()
main = return ()
