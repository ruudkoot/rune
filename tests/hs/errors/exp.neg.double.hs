-- Report 3.4: negation is not applied directly to a negation: not - - a.
module Main (main) where

main :: IO ()
main = print (- - 3)
