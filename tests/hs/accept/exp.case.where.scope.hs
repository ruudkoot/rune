-- Report 3.13: one where serves every guard of its alternative.
module Main (main) where

f :: Int -> Int
f x = case x of
  n | n > d -> 1
    | n < d -> 2
    where d = 3
  _ -> 0

main :: IO ()
main = return ()
