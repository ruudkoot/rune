-- Report 3.13: one alternative's where does not scope over the next.
module Main (main) where

f :: Int -> Int
f x = case x of
  1 -> d
    where d = 2
  _ -> d

main :: IO ()
main = return ()
