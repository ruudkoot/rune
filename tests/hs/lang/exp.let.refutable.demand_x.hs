-- Report 3.12: a refutable pattern binding that fails does nothing until a variable of it is demanded.
module Main (main) where

main :: IO ()
main = do
  print (let Just x = Nothing in 1 :: Int)
  print (let Just x = Nothing in x :: Int)
