-- rows: R49
-- Report 16.1.1: with a strict accumulating function, a bottom value in the list makes
-- its element bottom (when, the text and the code part on: readings.md R49, the lead's question).
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print (accumArray (+) 0 (1, 1) [(1, undefined)] ! (1 :: Int) :: Int)
