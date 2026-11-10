-- Report 3.17.2: (\ ~[x, (a,b)] -> x) [(0,1),bottom] is bottom: the inner tuple pattern is refutable.
module Main (main) where

main :: IO ()
main = print ((\ ~[x, (a, b)] -> x) [(0, 1), undefined :: (Int, Int)])
