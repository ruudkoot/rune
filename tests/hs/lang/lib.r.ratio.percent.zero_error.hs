-- Report 12.1: x % 0 is an error, "Ratio.% : zero denominator" in the Report's code.
module Main (main) where

import Ratio

main :: IO ()
main = do
  putStrLn "before"
  print (3 % 0 :: Rational)
