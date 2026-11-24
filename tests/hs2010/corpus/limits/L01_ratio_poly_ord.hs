-- Report: legal (Ord (Ratio a) needs only Integral a, T10 22).  Shim: base's Ord (Ratio a) needs base's Integral a.
module Main where
import Data.Ratio
less :: Integral a => Ratio a -> Ratio a -> Bool
less x y = x < y
main = print (less (1 % 2) (2 % 3 :: Rational))
