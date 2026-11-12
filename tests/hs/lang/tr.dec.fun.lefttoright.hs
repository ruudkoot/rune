-- rows: tr.dec.fun.seq R35 tr.dec.fun
-- Report 4.4.3.1: a function's clauses match left to right: g _ 0 = 1; g 0 _ = 2 makes g bottom 0 equal 1; a function of
-- two arguments applied to one is a value.
module Main (main) where

g :: Int -> Int -> Int
g _ 0 = 1
g 0 _ = 2

f :: Int -> Int -> Int
f x 0 = 1
f _ _ = 2

main :: IO ()
main = print (g undefined 0, seq (f undefined) (1 :: Int), seq f (1 :: Int))
