-- Report 4.4.1: unsigned, a group's uses within it share one type: f at Char and Bool.
module Main (main) where

f x = const x (g True)
g y = const y (f 'c', f True)

main :: IO ()
main = return ()
