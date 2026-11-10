-- rows: R45 R79
-- Report 6.4.5, chapter 11, readings.md R79: Complex's sqrt and log across their branch cut, signed zeros and all, as the
-- Report's Complex code (copied under new names) computes them.
module Main (main) where

import Complex

magnitude' :: Complex Double -> Double
magnitude' (x :+ y) = scaleFloat k (sqrt ((scaleFloat mk x) ^ 2 + (scaleFloat mk y) ^ 2))
  where k = max (exponent x) (exponent y)
        mk = - k

phase' :: Complex Double -> Double
phase' (0 :+ 0) = 0
phase' (x :+ y) = atan2 y x

sqrt' :: Complex Double -> Complex Double
sqrt' 0 = 0
sqrt' z@(x :+ y) = u :+ (if y < 0 then - v else v)
  where (u, v) = if x < 0 then (v', u') else (u', v')
        v' = abs y / (u' * 2)
        u' = sqrt ((magnitude' z + abs x) / 2)

log' :: Complex Double -> Complex Double
log' z = log (magnitude' z) :+ phase' z

same :: Complex Double -> Complex Double -> Bool
same (a :+ b) (c :+ d) = a == c && b == d && isNegativeZero b == isNegativeZero d

zs :: [Complex Double]
zs = [(-4) :+ 0, (-4) :+ (-0.0), (-1) :+ 0, (-1) :+ (-0.0), 3 :+ 4, 0 :+ (-2), (-2) :+ 1]

main :: IO ()
main = do
  print [same (sqrt z) (sqrt' z) | z <- zs]
  print [same (log z) (log' z) | z <- zs]
