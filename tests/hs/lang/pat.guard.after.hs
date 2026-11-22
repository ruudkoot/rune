-- rows: pat.guard.true pat.guard.env
-- Report 3.17.2: a guard is evaluated once all arguments have matched, must be True for the match to succeed, and sees the
-- where bindings and the pattern's variables.
module Main (main) where

f :: Int -> Int -> Int
f 0 y | undefined = 1
f _ _ = 2

g :: Int -> String
g x | x > 10 = "big"
    | d > 0 = "pos " ++ show d
  where d = x - 3
g _ = "small"

main :: IO ()
main = do
  print (f 1 2)
  print (map g [11, 5, 1])
