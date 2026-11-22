-- Report 4: a class declaration stands only at the top level: not in a let.
module Main (main) where

x :: Int
x = let class C a in 1

main :: IO ()
main = return ()
