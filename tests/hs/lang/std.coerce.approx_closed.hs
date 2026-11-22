-- rows: std.coerce.simpler R44
-- Report 6.4.6 and the Ratio library, with the erratum of August 2005 (readings.md R44): approxRational x eps is the
-- simplest rational in the closed interval [x - eps, x + eps], as the library's code, copied under a new name, gives.
module Main (main) where

import Ratio

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
xs = [(0.5, 0.5), (1.5, 0.5), (3.14159, 0.001), (-0.3, 0.05), (0.75, 0), (2, 0.1)]

main :: IO ()
main = do
  print (approxRational (0.5 :: Double) 0.5, approxRational (1.5 :: Double) 0.5)
  print [approxRational x e == approxRational' x e | (x, e) <- xs]
