-- Report 3.17.2: a numeric literal pattern k matches v if v == k, with the == of the pattern's type: a user instance's,
-- for an integer literal and for a floating one.
module Main (main) where

newtype O = O Int deriving Show

instance Eq O where
  O a == O b = a `mod` 2 == b `mod` 2

instance Num O where
  fromInteger i = O (fromInteger i)
  O a + O b = O (a + b)
  O a * O b = O (a * b)
  negate (O a) = O (negate a)
  abs (O a) = O (abs a)
  signum (O a) = O (signum a)

t :: O -> String
t 3 = "odd"
t _ = "even"

main :: IO ()
main = print (t (O 5), t (O 6))
