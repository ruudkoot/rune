-- rows: R10
-- Report 3.17.1, 3.17.3 (h): a negative literal pattern -1 is the expression negate (fromInteger 1) compared by ==
-- (readings.md R10).
module Main (main) where

newtype L = L String

instance Eq L where
  L a == L b = a == b

instance Show L where
  show (L s) = s

instance Num L where
  fromInteger i = L ("fromInteger " ++ show i)
  _ + _ = L "+"
  _ * _ = L "*"
  negate (L a) = L ("negate (" ++ a ++ ")")
  abs _ = L "abs"
  signum _ = L "signum"

g :: L -> String
g (-1) = "minus one"
g _ = "other"

main :: IO ()
main = do
  putStrLn (g (L "negate (fromInteger 1)"))
  putStrLn (g (L "fromInteger -1"))
