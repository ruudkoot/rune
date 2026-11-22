-- rows: R93
-- Report 4.3.4, readings.md R93 (implementation-defined): under default (Int, Double) an ambiguous Integral picks Int,
-- shown by 2^70's overflow, an error by D22's checked Int, where Integer would print it; 1/2 picks Double.
module Main (main) where

default (Int, Double)

main :: IO ()
main = do
  print (1 / 2)
  print (2 ^ 70)
