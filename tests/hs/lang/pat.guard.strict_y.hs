-- Report 3.17.2: the Report's example f ~(x,y,z) [a] | (a == y) = 1: the guard forces y, so f undefined [1] diverges.
module Main (main) where

f :: (Int, Int, Int) -> [Int] -> Int
f ~(x, y, z) [a] | (a == y) = 1

main :: IO ()
main = print (f undefined [1])
