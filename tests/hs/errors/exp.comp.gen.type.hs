-- Report 3.11: a generator's pattern has its list's element type.
module Main (main) where

xs = [x | (x, y) <- [1]]

main :: IO ()
main = return ()
