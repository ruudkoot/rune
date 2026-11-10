-- rows: pre.class.realfrac pre.class.realfrac.properfraction pre.class.realfrac.truncate pre.class.realfrac.round pre.class.realfrac.ceiling pre.class.realfrac.floor
-- Report 8: class RealFrac's defaults from properFraction: truncate, round (to even at the half), ceiling and floor;
-- every method defined overrides its default.
module Main (main) where

newtype A = A Double deriving (Eq, Ord, Show)
instance Num A where
  A x + A y = A (x + y)
  A x * A y = A (x * y)
  negate (A x) = A (negate x)
  abs (A x) = A (abs x)
  signum (A x) = A (signum x)
  fromInteger n = A (fromInteger n)
instance Real A where
  toRational (A x) = toRational x

instance Fractional A where
  A x / A y = A (x / y)
  fromRational r = A (fromRational r)
instance RealFrac A where
  properFraction (A x) = case properFraction x of (n, f) -> (n, A f)

newtype C = C Double deriving (Eq, Ord, Show)
instance Num C where
  C x + C y = C (x + y)
  C x * C y = C (x * y)
  negate (C x) = C (negate x)
  abs (C x) = C (abs x)
  signum (C x) = C (signum x)
  fromInteger n = C (fromInteger n)
instance Real C where
  toRational (C x) = toRational x

instance Fractional C where
  C x / C y = C (x / y)
  fromRational r = C (fromRational r)
instance RealFrac C where
  properFraction _ = (1, C 0)
  truncate _ = 2
  round _ = 3
  ceiling _ = 4
  floor _ = 5

xs :: [A]
xs = [A 2.5, A (-2.5), A 3.5, A 2.7]

main :: IO ()
main = do
  print (map truncate xs :: [Int], map round xs :: [Int], map ceiling xs :: [Int], map floor xs :: [Int])
  print (properFraction (A 3.75) :: (Int, A))
  print (properFraction (C 0) :: (Int, C), truncate (C 0) :: Int, round (C 0) :: Int, ceiling (C 0) :: Int, floor (C 0) :: Int)
