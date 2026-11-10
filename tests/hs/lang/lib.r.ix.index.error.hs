-- Report 15.2: index out of range is an error, "Ix.index: Index out of range." in the Report's code.
module Main (main) where

import Ix

main :: IO ()
main = do
  putStrLn "before"
  print (index (1, 5) (7 :: Int))
