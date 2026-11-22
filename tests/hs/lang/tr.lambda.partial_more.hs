-- Report 3.3: matching happens only once all n arguments are given: partly applied the lambda is a value, applied to all
-- it matches, and here diverges.
module Main (main) where

main :: IO ()
main = do
  print (seq ((\(x, y) z -> 1 :: Int) (undefined :: (Int, Int))) "ok")
  print ((\(x, y) z -> 1 :: Int) (undefined :: (Int, Int)) 'z')
