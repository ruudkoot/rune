-- Report 4.4.3.1: a where scopes over its clause alone.
module Main (main) where

f :: Int -> Int
f 0 = y
  where y = 1
f n = y

main :: IO ()
main = return ()
