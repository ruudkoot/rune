-- Report 12.1: % is strict in its numerator: the constructor's fields are strict.
module Main (main) where

import Ratio

main :: IO ()
main = do
  putStrLn "probe"
  print (denominator ((undefined :: Integer) % 1))
