-- rows: lib.ratio.type.rational lib.r.ratio.anyintegral lib.r.ratio.rational
-- Report 12: Ratio t for each Integral t, at Int and Integer; Ratio of kind * -> *; Rational is Ratio Integer,
-- interchangeable with it in signatures; the type derives Eq.
module Main (main) where

import Ratio

data K f = K (f Int)

k :: K Ratio
k = K (1 % 2)

r1 :: Ratio Int
r1 = 3 % 4

r2 :: Ratio Integer
r2 = 3 % 4

r3 :: Rational
r3 = r2

r4 :: Ratio Integer -> Rational
r4 x = x

r5 :: Rational -> Ratio Integer
r5 = r4

same :: Bool
same = r5 r3 == r2 && r1 /= 1 % 4

main :: IO ()
main = return ()
