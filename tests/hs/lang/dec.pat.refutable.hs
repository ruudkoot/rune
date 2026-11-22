-- Report 4.4.3.2: let [x] = [] in 1 is 1, and demanding x diverges.
module Main (main) where

main :: IO ()
main = do
  print (let [x] = [] in 1 :: Int)
  print (let [x] = [] in x :: Int)
