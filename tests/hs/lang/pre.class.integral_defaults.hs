-- rows: pre.class.integral pre.class.integral.quot pre.class.integral.rem pre.class.integral.div pre.class.integral.mod pre.class.integral.quotrem pre.class.integral.divmod pre.class.integral.tointeger
-- Report 8: class Integral's defaults from quotRem and toInteger: quot, rem, div, mod and divMod, the last by signum;
-- every method defined overrides its default.
module Main (main) where

newtype A = A Int deriving (Eq, Ord, Show)
instance Num A where
  A x + A y = A (x + y)
  A x * A y = A (x * y)
  negate (A x) = A (negate x)
  abs (A x) = A (abs x)
  signum (A x) = A (signum x)
  fromInteger n = A (fromInteger n)

instance Real A where
  toRational (A x) = toRational x

instance Enum A where
  toEnum = A
  fromEnum (A x) = x

instance Integral A where
  quotRem (A x) (A y) = let (q, r) = quotRem x y in (A q, A r)
  toInteger (A x) = toInteger x

newtype B = B Int deriving (Eq, Ord, Show)
instance Num B where
  B x + B y = B (x + y)
  B x * B y = B (x * y)
  negate (B x) = B (negate x)
  abs (B x) = B (abs x)
  signum (B x) = B (signum x)
  fromInteger n = B (fromInteger n)
instance Real B where
  toRational (B x) = toRational x
instance Enum B where
  toEnum = B
  fromEnum (B x) = x
instance Integral B where
  quotRem _ _ = (B 1, B 2)
  toInteger _ = 3
  quot _ _ = B 4
  rem _ _ = B 5
  div _ _ = B 6
  mod _ _ = B 7
  divMod _ _ = (B 8, B 9)

main :: IO ()
main = do
  print (map (\(x, y) -> (quot x y, rem x y, div x y, mod x y)) [(A 7, A 2), (A (-7), A 2), (A 7, A (-2))])
  print (divMod (A (-7)) (A 2), quotRem (A (-7)) (A 2), toInteger (A 5))
  print (quot (B 0) (B 0), rem (B 0) (B 0), div (B 0) (B 0), mod (B 0) (B 0))
  print (divMod (B 0) (B 0), quotRem (B 0) (B 0), toInteger (B 0))
