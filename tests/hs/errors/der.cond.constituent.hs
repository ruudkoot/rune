-- Report 10: each constituent type must be an instance: a function is no Eq.
module Main (main) where

data T = T (Int -> Int) deriving Eq

main :: IO ()
main = return ()
