-- Report 4.4.3: a function no clause of which matches is bottom.
module Main (main) where

f :: Int -> Int
f 0 = 1

main :: IO ()
main = do
  print (f 0)
  print (f 1)
