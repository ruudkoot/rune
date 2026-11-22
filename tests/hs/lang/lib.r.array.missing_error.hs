-- Report 16.1: an index in bounds with no association gives a bottom element.
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print (array (1, 3) [(1, 'a'), (3, 'c')] ! 2)
