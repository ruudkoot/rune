-- rows: exp.neg.e1paren exp.neg.minus.paren
-- Report 3.4: e1-e2 is binary -, e1(-e2) an application, and (-) is \x y -> x-y.
module Main (main) where

g :: Int -> Int
g x = x * 2

main :: IO ()
main = do
  let f = 10 :: Int
  print (f-1)
  print (g(-1))
  print ((-) 3 1 :: Int)
