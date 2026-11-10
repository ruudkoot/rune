-- rows: tr.op.infix exp.neg.literal R10
-- Report 3.4: e1 op e2 is (op) e1 e2, and -e is negate (e): a user Num instance sees negate, and -5 is negate
-- (fromInteger 5).
module Main (main) where

newtype L = L String

instance Eq L where
  L a == L b = a == b

instance Show L where
  show (L s) = s

instance Num L where
  fromInteger i = L ("fromInteger " ++ show i)
  L a + L b = L ("(" ++ a ++ " + " ++ b ++ ")")
  L a - L b = L ("(" ++ a ++ " - " ++ b ++ ")")
  _ * _ = L "*"
  negate (L a) = L ("negate (" ++ a ++ ")")
  abs _ = L "abs"
  signum _ = L "signum"

main :: IO ()
main = do
  print (- 5 :: L)
  print (1 - 2 :: L)
  print (1 + 2 :: L, (+) 1 2 :: L)
  print (let x = 3 :: L in - x)
