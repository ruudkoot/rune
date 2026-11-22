-- Report 4.5.5, Rule 1: a restricted group's constrained variables are not generalised.
module Main (main) where

main :: IO ()
main = print (let x = 1 in (x :: Int, x :: Double))
