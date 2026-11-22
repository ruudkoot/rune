-- rows: exp.case.nomatch
-- Report 3.1, 3.13, 3.17.3 (b): a case that no alternative matches is error "No match": it terminates.
module Main (main) where

f :: Int -> Int
f x = case x of
  1 -> 10
  2 -> 20

main :: IO ()
main = do
  print (f 2)
  print (f 3)
