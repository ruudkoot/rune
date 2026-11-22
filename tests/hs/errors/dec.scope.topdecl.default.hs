-- Report 4: a default declaration stands only at the top level: not in a let.
module Main (main) where

x :: Int
x = let default () in 1

main :: IO ()
main = return ()
