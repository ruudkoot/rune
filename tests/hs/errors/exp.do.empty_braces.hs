-- Report 3.14: a do ends in an expression, so it is not empty: not do {}.
module Main (main) where

main :: IO ()
main = do {}
