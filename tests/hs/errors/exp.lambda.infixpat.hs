-- Report 3.3: "\x:xs->x is syntactically incorrect" (the Report's example).
module Main (main) where

f :: [Int] -> Int
f = \x:xs->x

main :: IO ()
main = return ()
