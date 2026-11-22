-- Report 3, 3.4: negation is the only prefix operator: not ! x, for a ! of the program.
module Main (main) where

(!) :: Int -> Int -> Int
a ! b = a

x :: Int
x = ! 1

main :: IO ()
main = return ()
