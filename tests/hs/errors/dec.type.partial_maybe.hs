-- Report 4.2.2: a synonym is not partially applied: not Maybe (P Int).
module Main (main) where

type P a b = (a, b)

x :: Maybe (P Int)
x = Nothing

main :: IO ()
main = return ()
