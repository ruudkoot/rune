-- rows: tr.lit.float exp.lit.int.anybase pat.m.lit.interp R14
-- Report 3.2: an integer literal is fromInteger applied to an Integer, octal and hexadecimal ones too, and a floating
-- literal fromRational applied to a Rational; 3.17.2: in a pattern as well.
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
  negate _ = L "negate"
  abs _ = L "abs"
  signum _ = L "signum"

instance Fractional L where
  fromRational r = L ("fromRational " ++ show r)
  _ / _ = L "/"

g :: L -> String
g 7 = "seven"
g _ = "other"

main :: IO ()
main = do
  print (5 :: L)
  print (0o17 :: L, 0xF :: L)
  print (2.5 :: L)
  putStrLn (g (L "fromInteger 7"))
  putStrLn (g (L "7"))
