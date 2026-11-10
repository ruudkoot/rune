-- Report 4.2.1: a constructor with a context is applied only where it holds: ConsSet id needs Eq of a function.
module Main (main) where

data Eq a => Set a = NilSet | ConsSet a (Set a)

s :: Set (Int -> Int)
s = ConsSet id NilSet

main :: IO ()
main = return ()
