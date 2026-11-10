-- Report 4.3.4: a class of a standard library may take part: range (1, 3) needs (Ix a, Num a) and defaults to Integer.
module Main (main) where

import Ix

main :: IO ()
main = print (range (1, 3), index (10, 20) 15)
