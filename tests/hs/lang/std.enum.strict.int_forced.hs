-- rows: R80
-- Report 6.3.4, readings.md R80 (implementation-defined): [undefined ..] at Int is bottom once forced, and nothing before.
module Main (main) where

main :: IO ()
main = do
  print (let xs = [undefined ..] :: [Int] in length [xs, xs])
  print (seq ([undefined ..] :: [Int]) ())
