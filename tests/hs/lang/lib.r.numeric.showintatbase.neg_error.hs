-- Report 14.1: showIntAtBase is an error on a negative number.
module Main (main) where

import Char
import Numeric

main :: IO ()
main = do
  putStrLn "before"
  putStrLn (showIntAtBase 10 intToDigit (-5 :: Int) "")
