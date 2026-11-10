-- Report 3.15.2: the braces of a labelled construction "are not subject to layout": they are written.
module Main (main) where

data R = R { f :: Int }

r :: R
r = R
  f = 1

main :: IO ()
main = return ()
