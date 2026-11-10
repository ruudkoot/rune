-- rows: R40
-- Report 6.3.4: pred of a bounded type's minBound is an error.
module Main (main) where

main :: IO ()
main = print (pred LT)
