-- rows: R18
-- Report 4.5.5: "a simple pattern binding is ... a single variable" (R18, D32): (x, y) = ... is not one, so
-- its signature cannot lift the restriction.
module Main (main) where

(x, y) = (1, 2)
x :: Num a => a

main :: IO ()
main = print (x :: Int, x :: Double)
