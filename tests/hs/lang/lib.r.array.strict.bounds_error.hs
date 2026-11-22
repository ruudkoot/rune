-- rows: R155
-- Report 16.1: array is strict in its bounds: an association to check makes bottom bounds
-- bottom (with none, lib.r.array.strict.bounds_empty_error, R155).
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print (array undefined [(1, 'a')] `seq` ())
