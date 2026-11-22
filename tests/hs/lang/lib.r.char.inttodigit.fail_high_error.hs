-- Report 19: intToDigit fails unless its argument is in the range 0..15: 16.
module Main (main) where

import Char

main :: IO ()
main = do
  putStrLn "before"
  print (intToDigit 16)
