-- Report 4: a type declaration stands only at the top level of a module: not in a let.
module Main (main) where

x :: Int
x = let type T = Int in 1

main :: IO ()
main = return ()
