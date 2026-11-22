-- rows: R16
-- Report 3.17.1: K {} matches whatever K's arity (R16).
module Main (main) where

data F = F Int Int

f :: F -> Int
f (F {}) = 1

main :: IO ()
main = return ()
