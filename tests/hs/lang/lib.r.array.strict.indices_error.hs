-- Report 16.1: array is strict in the indices of its association list.
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print (array (1, 2) [(undefined, 'a')] `seq` ())
