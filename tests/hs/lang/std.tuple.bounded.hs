-- Report 6.1.4: tuples are Bounded where their components are.
module Main (main) where

main :: IO ()
main = print (maxBound :: (Bool, Ordering), minBound :: ((), Bool))
