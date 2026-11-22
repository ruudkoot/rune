-- Report 19: chr is toEnum restricted to Char, an error out of range: chr (-1).
module Main (main) where

import Char

main :: IO ()
main = do
  putStrLn "before"
  print (chr (-1))
