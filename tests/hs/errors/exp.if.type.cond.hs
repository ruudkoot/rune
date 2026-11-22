-- Report 3.6: the condition is a Bool: if 1 then 2 else 3 needs Num Bool.
module Main (main) where

x :: Int
x = if 1 then 2 else 3

main :: IO ()
main = return ()
