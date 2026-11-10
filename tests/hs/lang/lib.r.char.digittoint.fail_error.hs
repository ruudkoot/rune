-- Report 19: digitToInt fails unless its argument satisfies isHexDigit.
module Main (main) where

import Char

main :: IO ()
main = do
  putStrLn "before"
  print (digitToInt 'g')
