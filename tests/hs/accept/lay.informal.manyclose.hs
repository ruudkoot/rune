-- Report 2.7: "a single newline may actually terminate several layout lists".
module Main (main) where

f :: Int -> Int
f x = g x
  where g y = h y
          where h z = k z
                  where k w = w + 1
main :: IO ()
main = print (f 1)
