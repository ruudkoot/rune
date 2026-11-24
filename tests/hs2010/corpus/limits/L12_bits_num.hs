-- Report: Bits has a Num superclass (15.1).
module Main where
import Data.Bits
next :: Bits a => a -> a
next x = (x + 1) .&. complement 0
main = print (next (6 :: Int))
