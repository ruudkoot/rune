-- Report 3.14: a do ends in an expression, so a lone ; is no do: not do { ; }.
module Main (main) where

main :: IO ()
main = do { ; }
