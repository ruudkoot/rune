-- Report 16.1: array is strict in its bounds: an association to check makes bottom bounds
-- bottom (an empty list of associations is the lead's question: the code checks no bounds then).
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print (array undefined [(1, 'a')] `seq` ())
