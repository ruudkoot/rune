-- Report 4.1.2: the built-in type constructors are not qualified: not Prelude.[] Int.
module Main (main) where

x :: Prelude.[] Int
x = []

main :: IO ()
main = return ()
