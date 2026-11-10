-- Report 3.12: let (x,y) = undefined in e does nothing until x or y is demanded; demanding x diverges.
module Main (main) where

main :: IO ()
main = do
  print (let (x, y) = undefined in 1 :: Int)
  print (let (x, y) = undefined in x :: Int)
