-- Report 6.3.1: an Eq instance defining neither method loops in both: bottom.
module Main (main) where

data A = A
instance Eq A

main :: IO ()
main = do
  putStrLn "probe"
  print (A == A)
