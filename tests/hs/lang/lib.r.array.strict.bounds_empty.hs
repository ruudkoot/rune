-- rows: R155
-- Report 16.1, 16.4: with no association, the code checks no bounds, so array undefined [] is not bottom (readings.md
-- R155: the oracles split on the prose's strictness, so the code decides, the lead's ruling 28).
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print ((array undefined [] :: Array Int Char) `seq` ())
