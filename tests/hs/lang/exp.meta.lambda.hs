-- rows: exp.meta.let exp.meta.if
-- Report 3: lambda, let and if extend as far to the right as possible.
module Main (main) where

main :: IO ()
main = do
  print ((\x -> x + 1) (2 :: Int))
  print (let {y = 1} in y + 1 :: Int)
  print (if True then 1 else 2 + 1 :: Int, if False then 1 else 2 + 1 :: Int)
