-- Report 4.5.1: mutually recursive bindings are one group, monomorphic in it: f at Char and Bool.
module Main (main) where

f x = const x (g 1)
g y = const y (f 'c', f True)

main :: IO ()
main = return ()
