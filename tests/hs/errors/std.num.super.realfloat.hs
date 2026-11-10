-- Report 6.4: RealFloat is a subclass of RealFrac and Floating: none without Floating.
module Main (main) where

newtype T = T Double deriving (Eq, Ord, Show)
instance Num T where
  T a + T b = T (a + b)
  T a * T b = T (a * b)
  abs = id
  signum = id
  negate (T a) = T (negate a)
  fromInteger = T . fromInteger
instance Real T where
  toRational (T a) = toRational a
instance Fractional T where
  T a / T b = T (a / b)
  fromRational = T . fromRational
instance RealFrac T where
  properFraction (T a) = let (n, f) = properFraction a in (n, T f)
instance RealFloat T where
  floatRadix _ = 2
  floatDigits _ = 53
  floatRange _ = (0, 0)
  decodeFloat (T a) = decodeFloat a
  encodeFloat m e = T (encodeFloat m e)
  isNaN _ = False
  isInfinite _ = False
  isDenormalized _ = False
  isNegativeZero _ = False
  isIEEE _ = True

main :: IO ()
main = return ()
