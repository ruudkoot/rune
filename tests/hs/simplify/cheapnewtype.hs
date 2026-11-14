-- core-cheap (D51) and a newtype: a let of a newtype's type whose value is
-- cheap and total -- a cast of a primitive on a literal, or on a strict
-- field, evaluated -- stays a let, for a case does not take a newtype's
-- value, only a cast of it to what it wraps (CoreLint: a case on a
-- newtype). pre.class.realfloat_defaults's atan2 at -O2 found it.
module Main (main) where

newtype A = A Double deriving (Show)
newtype B = B Bool deriving (Show)
newtype W a = W a deriving (Show)

keep :: Int -> a -> a
keep 0 a = a
keep n a = keep (n - 1) a

half :: Double -> A
half x = A (x / 2)

data P = P !Double

three :: P -> IO ()
three (P d) = print (keep 2 (half d), keep 2 (B (d < 3)), keep 2 (W (A (d * 2))))

main :: IO ()
main = do
  print (keep 3 (A (negate 1.5)))
  let d = sum (map fromIntegral [1, 2 :: Int]) :: Double
  three (P d)
