-- rows: R80
-- Report 6.3.4, readings.md R80 (implementation-defined): [1 .. undefined] at Integer is bottom once forced, and nothing before.
module Main (main) where

main :: IO ()
main = do
  print (let xs = [1 .. undefined] :: [Integer] in length [xs])
  print (seq ([1 .. undefined] :: [Integer]) ())
