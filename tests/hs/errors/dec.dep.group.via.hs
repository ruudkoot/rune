-- Report 4.5.1: the recursion may run through other bindings: a cycle of three.
module Main (main) where

f x = const x (h 1)
h y = const y (k 1)
k z = const z (f 'c', f True)

main :: IO ()
main = return ()
