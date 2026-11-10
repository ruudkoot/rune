-- rows: R45
-- Report 6.4.2, 8 (readings.md R45; D38: the text decides): gcd 0 0 is error "Prelude.gcd: gcd 0 0 is undefined".
module Main (main) where

main :: IO ()
main = do
  print (gcd 0 5 :: Int)
  print (gcd 0 0 :: Int)
