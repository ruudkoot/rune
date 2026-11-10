-- rows: R40
-- Report 6.3.4: succ of a bounded type's maxBound is an error.
module Main (main) where

main :: IO ()
main = print (succ True)
