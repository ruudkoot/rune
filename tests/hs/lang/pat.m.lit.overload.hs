-- Report 3.17.2: == is the pattern type's, for a floating literal too: fromRational of it, compared by a user ==.
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

instance Fractional O where
  fromRational r = O (truncate r)
  O a / O b = O (a `div` b)

u :: O -> String
u 4.5 = "even"
u _ = "odd"

main :: IO ()
main = print (u (O 8), u (O 9))
