-- Literals (3.2, 3.17.2): an integer literal is fromInteger of an Integer, a floating one fromRational of a Rational,
-- in an expression and in a pattern, where it is compared by ==; a negative literal pattern is negate of the literal.
module Main (main) where

newtype L = L String

instance Eq L where
  L a == L b = a == b

instance Show L where
  show (L s) = s

instance Num L where
  fromInteger i = L ("fromInteger " ++ show i)
  L a + L b = L (a ++ "+" ++ b)
  _ * _ = L "*"
  negate (L a) = L ("negate (" ++ a ++ ")")
  abs _ = L "abs"
  signum _ = L "signum"

instance Fractional L where
  fromRational r = L ("fromRational " ++ show (numerator' r) ++ "/" ++ show (denominator' r))
  _ / _ = L "/"

numerator' :: Rational -> Integer
numerator' r = truncate (r * 1000) `div` 1000

denominator' :: Rational -> Integer
denominator' _ = 1

seven :: L -> String
seven 7 = "seven"
seven (-1) = "minus one"
seven _ = "other"

small :: Int -> String
small 0 = "zero"
small 1 = "one"
small (-3) = "minus three"
small _ = "many"

big :: Integer -> Int
big 100000000000000000000 = 1
big _ = 0

half :: Double -> String
half 0.5 = "half"
half _ = "not half"

main :: IO ()
main = do
  print (5 :: L)
  print (0x10 :: L, 0o10 :: L)
  print (2 + 3 :: L)
  print (- 4 :: L)
  print (2.5 :: L)
  putStrLn (seven (L "fromInteger 7"))
  putStrLn (seven (L "negate (fromInteger 1)"))
  putStrLn (seven 9)
  putStrLn (concatMap small [0, 1, -3, 4])
  print (big (10 ^ 20), big 1)
  putStrLn (half 0.5)
  putStrLn (half 0.25)
  print (length (filter (== 0.5) [0.5, 1.5, 0.5 :: Double]))
