-- Report 4.5.1: the variables of one pattern binding are one group: f used at two types in it.
module Main (main) where

(f, g) = (\x -> x, (f 1, f 'c'))

main :: IO ()
main = return ()
