-- Report 2.2: digit -> ascDigit | uniDigit; uniDigit -> any Unicode decimal digit: U+0661 continues an identifier.
module Main (main) where

main :: IO ()
main = print x١
  where x١ = 1 :: Int
