-- rows: std.lit.float std.pow.int
-- Report 6.4.1: an integer literal is fromInteger at its type, a floating one fromRational: at Int, Double, Float,
-- Rational and a user type whose methods show they ran; ^ at Int, Double and the user type.
module Main (main) where

newtype L = L String

instance Eq L where
  L a == L b = a == b

instance Show L where
  show (L s) = s

instance Num L where
  fromInteger i = L ("fromInteger " ++ show i)
  L a + L b = L (a ++ "+" ++ b)
  L a * L b = L (a ++ "*" ++ b)
  negate _ = L "negate"
  abs _ = L "abs"
  signum _ = L "signum"

instance Fractional L where
  fromRational r = L ("fromRational " ++ show r)
  _ / _ = L "/"

main :: IO ()
main = do
  print (1 :: Int, 1 :: Double, 1 :: L)
  print (1.5 :: Float, 1.5 :: Rational, 1.5 :: L)
  print (2 ^ 10 :: Int, 2 ^ 10 :: Double, 2 ^ (2 :: Int) :: L)
