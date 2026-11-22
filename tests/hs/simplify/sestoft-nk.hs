-- An n+k pattern matches by the type's (>=) and binds by its (-)
-- (3.17.2): K's (>=) is an error at 99, so Sestoft's trees (D34's B) must
-- call it where the Report's order does and nowhere else.
-- sestoft: as A
module Main where

newtype K = K Int deriving Show

instance Eq K where
  K a == K b = a == b

instance Ord K where
  compare (K a) (K b) = compare a b
  K a >= K b | a == 99 = error "(>=) at 99"
             | otherwise = a >= b

instance Num K where
  K a + K b = K (a + b)
  K a - K b = K (a - b)
  K a * K b = K (a * b)
  negate (K a) = K (negate a)
  abs (K a) = K (abs a)
  signum (K a) = K (signum a)
  fromInteger n = K (fromInteger n)

instance Real K where
  toRational (K a) = toRational a

instance Enum K where
  toEnum = K
  fromEnum (K a) = a

instance Integral K where
  quotRem (K a) (K b) = let (q, r) = quotRem a b in (K q, K r)
  toInteger (K a) = toInteger a

k :: K -> Bool -> Int
k _ True = 0
k (n+1) False = 1 + fromEnum n
k _ _ = -1

main :: IO ()
main = do
  print (k (K 99) True)
  print (k (K 5) False)
  print (k (K 0) False)
  print (k (K 99) False)
