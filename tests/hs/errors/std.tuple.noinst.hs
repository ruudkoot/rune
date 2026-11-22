-- Report 6.1.4: tuples are in Eq where their components are: not (id, 1).
module Main (main) where

x :: Bool
x = (id, 1) == (id, 1)

main :: IO ()
main = return ()
