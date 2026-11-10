-- Report 3.15.3, 4.2.1: updating a strict field to bottom gives bottom: the update builds the value with the constructor,
-- which is strict there.
module Main (main) where

data S = S {s :: !Int, t :: Int}

main :: IO ()
main = print (seq ((S 1 2) {s = undefined}) ())
