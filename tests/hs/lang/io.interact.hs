-- Report 7.1: interact passes the whole input to its function and writes the result (map toUpper, with import Char).
module Main (main) where

import Char

main :: IO ()
main = interact (map toUpper)
