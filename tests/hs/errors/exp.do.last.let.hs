-- Report 3.14: the last statement must be an expression, not a let: not do { let x = 1 }.
module Main (main) where

main :: IO ()
main = do { let x = () }
