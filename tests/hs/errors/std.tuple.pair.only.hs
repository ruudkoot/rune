-- Report 6.1.4: fst and snd are of pairs, and no such functions are predefined for larger tuples.
module Main (main) where

x :: Int
x = fst (1, 2, 3)

main :: IO ()
main = return ()
