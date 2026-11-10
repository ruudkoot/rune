-- Report 9.3, equation 1: a line that begins with an operator at its block's column gets a ; before it.
module Main (main) where

main :: IO ()
main = do
  print (1
  + 2)
