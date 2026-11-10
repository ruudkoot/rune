-- Report 12.1: % is strict in its denominator: reduce matches it against 0.
module Main (main) where

import Ratio

main :: IO ()
main = do
  putStrLn "probe"
  print (numerator (1 % (undefined :: Integer)))
