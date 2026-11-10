-- Report 3.15.2: a construction names every strict field.
module Main (main) where

data S = S {a :: !Int, b :: Int}

v :: S
v = S {b = 1}

main :: IO ()
main = return ()
