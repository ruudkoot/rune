-- rows: lib.ratio.numerator lib.ratio.denominator lib.ratio.reduce.def lib.ratio.ratprec.def lib.ratio.approxrational lib.r.ratio.percent.reduce lib.r.ratio.percent.sign lib.r.ratio.components lib.r.ratio.example.1 lib.r.ratio.example.2 lib.r.ratio.approx.simplest lib.r.ratio.approx.interval R44
-- Report 12.1: %, numerator, denominator and approxRational against the Report's own definitions (with reduce and
-- ratPrec) copied over a type of their own: % reduces and gives a positive denominator, 12 % 8 is 3 % 2 and
-- 12 % (-8) is (-3) % 2, and approxRational is the simplest rational in the closed interval of the erratum of
-- August 2005.
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

pairs :: [(Integer, Integer)]
pairs = [(12, 8), (12, -8), (-12, 8), (-12, -8), (0, 5), (0, -5), (7, 1), (1, -2), (3, 9), (-6, 4)]

approxRational' :: (RealFrac a) => a -> a -> Rational
approxRational' rat eps = simplest (rat - eps) (rat + eps)
  where simplest x y | y < x = simplest y x
                    | x == y = xr
                    | x > 0 = simplest' n d n' d'
                    | y < 0 = - simplest' (- n') d' (- n) d
                    | otherwise = 0 % 1
          where xr = toRational x
                n = numerator xr
                d = denominator xr
                nd' = toRational y
                n' = numerator nd'
                d' = denominator nd'
        simplest' n d n' d' | r == 0 = q % 1
                             | q /= q' = (q + 1) % 1
                             | otherwise = (q * n'' + d'') % n''
          where (q, r) = quotRem n d
                (q', r') = quotRem n' d'
                nd'' = simplest' d' r' d r
                n'' = numerator nd''
                d'' = denominator nd''

xs :: [(Double, Double)]
xs = [(3.14, 0.01), (0.5, 0.5), (1.5, 0.5), (-0.3, 0.05), (0.75, 0), (2, 0.1), (0.333, 0.001)]

main :: IO ()
main = do
  print [same (x % y) (pct x y) | (x, y) <- pairs]
  print (numerator (12 % 8 :: Rational), denominator (1 % (-2) :: Rational))
  print [(numerator r, denominator r) | (x, y) <- [(-6, 4), (6, -4), (-6, -4)], let r = x % y :: Ratio Int]
  print (12 % 8 :: Rational)
  print (12 % (-8) :: Rational)
  print (showsPrec ratPrec' (1 % 2 :: Rational) "", showsPrec (ratPrec' + 1) (1 % 2 :: Rational) "")
  print (approxRational (3.14 :: Double) 0.01, approxRational (0.5 :: Double) 0.5, approxRational (1.5 :: Double) 0.5)
  print [approxRational x e == approxRational' x e | (x, e) <- xs]
