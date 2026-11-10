-- Report 3.5: "(a+b+) is valid", as + is left associative (the Report's example).
module Main (main) where

main :: IO ()
main = print ((a+b+) 1)
  where
    a = 2 :: Int
    b = 3
