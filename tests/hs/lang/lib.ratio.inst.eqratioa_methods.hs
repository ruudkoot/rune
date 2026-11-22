-- rows: lib.ratio.inst.ordratioa lib.ratio.inst.numratioa lib.ratio.inst.realratioa lib.ratio.inst.fractionalratioa lib.ratio.inst.realfracratioa lib.ratio.inst.enumratioa lib.ratio.inst.readratioa lib.ratio.inst.showratioa lib.r.ratio.lift
-- Report 12.1: the instances of Ratio a, each method on samples, against the Report's code copied over a type of its
-- own where the Report gives code (Ord, Num, Real, Fractional, RealFrac's properFraction, Read, Show), and Enum by
-- numericEnumFrom and its kin; Eq is derived.
module Main (main) where

import Ratio

data Q = !Integer :%% !Integer

reduce' :: Integer -> Integer -> Q
reduce' _ 0 = error "Ratio.% : zero denominator"
reduce' x y = (x `quot` d) :%% (y `quot` d)
  where d = gcd x y

pct :: Integer -> Integer -> Q
pct x y = reduce' (x * signum y) (abs y)

num, den :: Q -> Integer
num (x :%% _) = x
den (_ :%% y) = y

same :: Rational -> Q -> Bool
same r q = numerator r == num q && denominator r == den q

ratPrec' :: Int
ratPrec' = 7

qcmp :: Q -> Q -> (Bool, Bool)
qcmp (x :%% y) (x' :%% y') = (x * y' <= x' * y, x * y' < x' * y)

qadd, qmul, qdiv :: Q -> Q -> Q
qadd (x :%% y) (x' :%% y') = reduce' (x * y' + x' * y) (y * y')
qmul (x :%% y) (x' :%% y') = reduce' (x * x') (y * y')
qdiv (x :%% y) (x' :%% y') = pct (x * y') (y * x')

qneg, qabs, qsig, qrecip :: Q -> Q
qneg (x :%% y) = (- x) :%% y
qabs (x :%% y) = abs x :%% y
qsig (x :%% y) = signum x :%% 1
qrecip (x :%% y) = pct y x

qprop :: Q -> (Integer, Q)
qprop (x :%% y) = (fromIntegral q, r :%% y)
  where (q, r) = quotRem x y

toQ :: Rational -> Q
toQ r = numerator r :%% denominator r

eqQ :: Q -> Q -> Bool
eqQ (a :%% b) (c :%% d) = a == c && b == d

pq :: (Integer, Q) -> (Integer, Q) -> Bool
pq (n, q) (m, r) = n == m && eqQ q r

rs :: [Rational]
rs = [3 % 4, (-3) % 4, 5 % 1, 0, 7 % 2, (-7) % 2, 1 % 3]

main :: IO ()
main = do
  print [(a == b, a /= b) | a <- [3 % 4, 6 % 8 :: Rational], b <- [3 % 4, 1 % 4]]
  print (and [(a <= b, a < b) == qcmp (toQ a) (toQ b) | a <- rs, b <- rs], compare (1 % 3) (1 % 2 :: Rational), max (1 % 3) (1 % 2 :: Rational), min (1 % 3) (1 % 2 :: Rational))
  print (and [eqQ (toQ (a + b)) (qadd (toQ a) (toQ b)) && eqQ (toQ (a * b)) (qmul (toQ a) (toQ b)) | a <- rs, b <- rs])
  print (and [eqQ (toQ (negate a)) (qneg (toQ a)) && eqQ (toQ (abs a)) (qabs (toQ a)) && eqQ (toQ (signum a)) (qsig (toQ a)) | a <- rs])
  print ((3 % 4) - (1 % 4) :: Rational, fromInteger 7 :: Rational, toRational (3 % 4 :: Ratio Int))
  print (and [eqQ (toQ (a / b)) (qdiv (toQ a) (toQ b)) | a <- rs, b <- rs, b /= 0], and [eqQ (toQ (recip a)) (qrecip (toQ a)) | a <- rs, a /= 0])
  print (fromRational (3 % 4) :: Ratio Int, recip ((-3) % 4 :: Rational))
  print (and [(\(n, f) -> (n, toQ f)) (properFraction a :: (Integer, Rational)) `pq` qprop (toQ a) | a <- rs])
  print (properFraction ((-7) % 2 :: Rational) :: (Integer, Rational))
  print (map truncate rs :: [Integer], map round rs :: [Integer], map ceiling rs :: [Integer], map floor rs :: [Integer])
  print (round (5 % 2 :: Rational) :: Integer, round (7 % 2 :: Rational) :: Integer, round ((-5) % 2 :: Rational) :: Integer)
  print (succ (1 % 2 :: Rational), pred (1 % 2 :: Rational), toEnum 3 :: Rational, fromEnum (7 % 2 :: Rational), fromEnum ((-7) % 2 :: Rational))
  print (take 3 [1 % 2 :: Rational ..], [1 % 2, 1 .. 3 :: Rational], [1 % 2 .. 2 :: Rational], [3, 5 % 2 .. 1 :: Rational])
  print (read "3 % 4" :: Rational, read " ( 3 % 4 ) " :: Rational, read "(-3) % 4" :: Rational, read "6 % 8" :: Ratio Int)
  print (readsPrec 8 "3 % 4" :: [(Rational, String)], readsPrec 7 "3 % 4 rest" :: [(Rational, String)])
  print (show (3 % 4 :: Rational), showsPrec 8 (3 % 4 :: Rational) "", show [Just ((-1) % 3 :: Rational)])
