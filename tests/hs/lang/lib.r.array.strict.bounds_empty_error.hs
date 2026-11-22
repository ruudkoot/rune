-- rows: R155
-- Report 16.1: array is strict in its bounds with no association too, as the prose says (readings.md R155:
-- the code checks no bounds then, but D52's judges and third take the prose, the lead's ruling 35).
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print ((array undefined [] :: Array Int Char) `seq` ())
