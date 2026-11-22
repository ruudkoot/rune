-- Report 6.4.2: quot, rem, div and mod apply to integral numbers alone: not 1.5 `div` 2.
module Main (main) where

main :: IO ()
main = print (1.5 `div` 2)
