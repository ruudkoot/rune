-- Report 4.2.1: a match against a constructor with a context gives rise to it: Set a -> a without Eq a.
module Main (main) where

data Eq a => Set a = NilSet | ConsSet a (Set a)

f :: Set a -> a
f (ConsSet a _) = a

main :: IO ()
main = return ()
