-- Report 2010: n+k patterns are gone (rejected).
module Main where
f :: Int -> Int
f (n+1) = n
f _ = 0
main = print (f 3)
