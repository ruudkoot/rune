-- Report 2.4, the table of samples: `f.g` lexes as `f . g`, three tokens.
module Main (main) where

main :: IO ()
main = print ((f.g) 1)
  where
    f = negate :: Int -> Int
    g = succ
