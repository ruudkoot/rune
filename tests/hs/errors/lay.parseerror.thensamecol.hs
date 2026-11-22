-- Report 9.3, equation 1: a then at the column of its do block gets a ; before it, and is refused.
module Main (main) where

main :: IO ()
main = do
  if True
  then print 1
  else print 2
