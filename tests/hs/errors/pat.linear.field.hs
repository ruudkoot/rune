-- Report 3.17.1: C {f1 = x, f2 = x} is not linear.
module Main (main) where

data C = C {f1, f2 :: Int}

g :: C -> Int
g (C {f1 = x, f2 = x}) = x

main :: IO ()
main = return ()
