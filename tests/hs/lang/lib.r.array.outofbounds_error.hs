-- Report 16.1: the array is bottom if any index of its list is out of bounds.
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print (array (1, 2) [(3, 'a')] `seq` ())
