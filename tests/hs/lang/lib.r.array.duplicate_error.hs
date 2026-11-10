-- Report 16.1: two associations of one index make that element bottom.
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print (array (1, 2) [(1, 'a'), (1, 'b'), (2, 'c')] ! 1)
