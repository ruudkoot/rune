-- Report 3.11: a guard is a Bool.
module Main (main) where

xs = [x | x <- "ab", 'a']

main :: IO ()
main = return ()
