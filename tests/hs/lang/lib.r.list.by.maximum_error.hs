-- Report 17.6: maximumBy of the empty list is an error.
module Main (main) where

import List

main :: IO ()
main = do
  putStrLn "before"
  print (maximumBy compare ([] :: [Int]))
