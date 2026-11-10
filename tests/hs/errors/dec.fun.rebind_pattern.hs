-- Report 4.4.3.1: nor by a function and a pattern binding: f twice.
module Main (main) where

f x = 1
(f, y) = (id, 2)

main :: IO ()
main = return ()
