-- rows: R81
-- Report 6.3.4, 6.4, readings.md R81 (implementation-defined): fromEnum of a value past Int's range is an error.
module Main (main) where

data W = W Integer deriving Show

instance Enum W where
  toEnum = W . toInteger
  fromEnum (W n) = fromInteger n

main :: IO ()
main = do
  print (fromEnum (W 7))
  print (fromEnum (W (2 ^ 70)))
