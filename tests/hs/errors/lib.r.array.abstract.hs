-- Report 16: Array is abstract: its constructor MkArray is not exported.
module Main (main) where

import Array

x :: Array Int Int
x = MkArray (0, 0) id

main :: IO ()
main = return ()
