-- rows: R155
-- Report 16.1: array is strict in its bounds: an association to check makes bottom bounds
-- bottom (with no association the code checks no bounds: lib.r.array.strict.bounds_empty, R155).
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print (array undefined [(1, 'a')] `seq` ())
