-- Report 4.2.1: data T = C !Int Int: the first strict, the second not.
module Main (main) where

data T = C !Int Int

first :: T -> Int
first (C a _) = a

main :: IO ()
main = do
  print (first (C 1 undefined))
  print (first (C undefined 2))
