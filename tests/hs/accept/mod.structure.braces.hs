-- Report 5.1: a module body may use explicit braces.
module Main (main) where { x :: Int ; x = 1 ; main :: IO () ; main = print x }
