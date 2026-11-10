-- Report 4.5.5, Rule 2: a variable left that does not default is an error: read's a.
module Main (main) where

x = read "1"

main :: IO ()
main = print 1
