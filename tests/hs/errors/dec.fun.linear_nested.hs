-- Report 4.4.3.1: nor across them: f (x, y) [x].
module Main (main) where

f :: (Int, Int) -> [Int] -> Int
f (x, y) [x] = 1
f _ _ = 0

main :: IO ()
main = return ()
