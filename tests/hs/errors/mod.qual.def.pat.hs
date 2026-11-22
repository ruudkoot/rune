-- Report 5.5.1: nor for a variable bound by a pattern: not f M.x = 1.
module Main (main) where

f :: Int -> Int
f Main.x = 1

main :: IO ()
main = return ()
