-- Report 8 and the List library: the generic functions are List's: genericLength at Integer.
module Main (main) where

import List

main :: IO ()
main = print (genericLength [1, 2, 3 :: Int] :: Integer, genericTake (2 :: Integer) "abc")
