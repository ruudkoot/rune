-- Report 2.7, the same rule: where closes an implicit do block it cannot belong to.
module Main (main) where

main :: IO ()
main = do print x where x = 1 :: Int
