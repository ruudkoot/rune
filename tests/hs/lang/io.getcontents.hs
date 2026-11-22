-- Report 7.1: getContents returns all the input as one string.
module Main (main) where

main :: IO ()
main = do
  s <- getContents
  print (lines s)
