-- rows: pat.m.npk.bind pat.m.npk.fail pat.m.npk.overload pat.m.npk.literal tr.case.s R15
-- Report 3.17.2, with the erratum of March 2008 (v for x): n+k matches v if v >= k, binding n to v - k, and fails
-- otherwise; >=, - and the literal k are those of the pattern's type; 3.17.3 (s).
module Main (main) where

f :: Int -> Int
f (n + 2) = n
f _ = 0

newtype I = I Int deriving (Eq, Show)

instance Ord I where
  compare _ _ = EQ
  _ >= _ = True

instance Num I where
  fromInteger i = I (fromInteger i * 10)
  I a + I b = I (a + b)
  I a - I b = I (a * 100 + b)
  I a * I b = I (a * b)
  negate (I a) = I (negate a)
  abs (I a) = I (abs a)
  signum (I a) = I (signum a)

instance Real I where
  toRational (I a) = toRational a

instance Enum I where
  toEnum = I
  fromEnum (I a) = a

instance Integral I where
  toInteger (I a) = toInteger a
  quotRem (I a) (I b) = let (q, r) = quotRem a b in (I q, I r)

g :: I -> I
g (n + 2) = n

main :: IO ()
main = do
  print (f 5, f 2, f 1)
  print (g (I 1))
  print (case 7 :: Int of { x + 2 -> x; _ -> 0 }, if (7 :: Int) >= 2 then (\x -> x) (7 - 2) else 0)
