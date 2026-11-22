-- Report 3.10 and 2.4: F.. lexes as a qualified dot, so [False..] is no sequence ([False ..] is).
module Main (main) where

main :: IO ()
main = print [False..]
