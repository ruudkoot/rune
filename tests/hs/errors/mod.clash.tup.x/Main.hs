-- Report 5.5.2: in the Report's tup the reference to x is ambiguous.
module Main (main) where

import B
import C
import D

main :: IO ()
main = print (b, c, d, x)
