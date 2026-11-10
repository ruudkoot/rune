-- Report 16.1: indexing an empty array is an error.
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print ((array (2, 1) [] :: Array Int Char) ! 1)
