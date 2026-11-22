-- Report 10: Pair a b is Bounded where a and b are: Integer is not.
module Main (main) where

data Pair a b = Pair a b deriving Bounded

x :: Pair Integer Bool
x = minBound

main :: IO ()
main = return ()
