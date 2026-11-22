-- Report 3.14: "The last statement in a do expression must be an expression": not do { x <- e }.
module Main (main) where

main :: IO ()
main = do { x <- return () }
