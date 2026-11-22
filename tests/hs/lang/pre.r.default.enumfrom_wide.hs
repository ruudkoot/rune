-- rows: R81
-- Report 8, readings.md R81 (implementation-defined): the default enumFrom goes through fromEnum, which past Int's range is an
-- error.
module Main (main) where

data W = W Integer deriving Show

instance Enum W where
  toEnum = W . toInteger
  fromEnum (W n) = fromInteger n

main :: IO ()
main = do
  print (take 2 [W 3 ..])
  print (case [W (2 ^ 70) ..] of (W n : _) -> n == 2 ^ 70)
