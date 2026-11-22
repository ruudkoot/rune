-- Report 4.4.1: a signature no more general than the principal type: not (Num a, Num b) => a -> b.
module Main (main) where

sqr :: (Num a, Num b) => a -> b
sqr x = x * x

main :: IO ()
main = return ()
