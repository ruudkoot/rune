-- Report 9.3, equation 10 needs m /= 0: an implicit close never matches an explicit open.
module Main (main) where

main :: IO ()
main = print (do { 1 in 2 })
