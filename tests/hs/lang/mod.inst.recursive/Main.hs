-- rows: R94
-- Report 5.7, readings.md R94 (no oracle: the output is the text's): A and B import each other; B's instances
-- reach Main round the cycle through A.
module Main (main) where

import A

main :: IO ()
main = do
  putStrLn useA
  print (T 2)
