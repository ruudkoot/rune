-- Report 4.2.1: ! is an ordinary varsym outside the argument types of a data declaration.
module Main (main) where

(!) :: Int -> Int -> Int
a ! b = a + b

main :: IO ()
main = print (1 ! 2, (!) 1 2)
