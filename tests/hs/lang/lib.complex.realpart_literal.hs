-- rows: lib.complex.imagpart lib.complex.conjugate lib.complex.mkpolar lib.complex.cis lib.complex.polar lib.complex.magnitude lib.complex.phase lib.r.complex.algebraic lib.r.complex.mkpolar lib.r.complex.cis lib.r.complex.polar.magnitude lib.r.complex.polar.phase lib.r.complex.polar.zero lib.r.complex.parts lib.r.complex.polarparts lib.r.complex.conjugate
-- Report 13.1: realPart, imagPart, conjugate, mkPolar, cis, polar, magnitude and phase against the Report's own
-- definitions copied under new names (a client matching on :+), the transcendental ones to a tolerance: the
-- magnitude is not negative and scaled (1.0e300 :+ 1.0e300 does not overflow), the phase is in (-pi, pi] and pi on
-- the negative real axis, 0 where the magnitude is, signed zeros too; cis t has magnitude 1 and phase t modulo 2 pi.
module Main (main) where

import Complex

near :: Double -> Double -> Bool
near a b = abs (a - b) <= 1.0e-12 * maximum [1, abs a, abs b]

nearC :: Complex Double -> Complex Double -> Bool
nearC (a :+ b) (c :+ d) = near a c && near b d

realPart', imagPart' :: Complex Double -> Double
realPart' (x :+ y) = x
imagPart' (x :+ y) = y

conjugate' :: Complex Double -> Complex Double
conjugate' (x :+ y) = x :+ (- y)

mkPolar' :: Double -> Double -> Complex Double
mkPolar' r theta = r * cos theta :+ r * sin theta

cis' :: Double -> Complex Double
cis' theta = cos theta :+ sin theta

polar' :: Complex Double -> (Double, Double)
polar' z = (magnitude' z, phase' z)

magnitude' :: Complex Double -> Double
magnitude' (x :+ y) = scaleFloat k (sqrt ((scaleFloat mk x) ^ 2 + (scaleFloat mk y) ^ 2))
  where k = max (exponent x) (exponent y)
        mk = - k

phase' :: Complex Double -> Double
phase' (0 :+ 0) = 0
phase' (x :+ y) = atan2 y x

zs :: [Complex Double]
zs = [3 :+ 4, (-3) :+ 4, (-3) :+ (-4), 3 :+ (-4), 0 :+ 0, 0 :+ 2, (-1) :+ 0, 1.0e300 :+ 1.0e300, 1.5 :+ (-0.5)]

main :: IO ()
main = do
  print [realPart z == realPart' z && imagPart z == imagPart' z && conjugate z == conjugate' z | z <- zs]
  print [near (magnitude z) (magnitude' z) && near (phase z) (phase' z) | z <- zs]
  print [near (fst (polar z)) (fst (polar' z)) && near (snd (polar z)) (snd (polar' z)) | z <- zs]
  print [nearC (mkPolar r t) (mkPolar' r t) && nearC (cis t) (cis' t) | r <- [0, 1, 2.5], t <- [0, 0.5, 2, -1, 4]]
  print (all (>= 0) (map magnitude zs), all (\z -> phase z > - pi && phase z <= pi) zs, phase ((-1) :+ 0) == pi)
  print (polar (0 :+ 0), polar ((-0.0) :+ (-0.0)), isNegativeZero (phase ((-0.0) :+ 0)))
  print (magnitude (1.0e300 :+ 1.0e300) < 1 / 0, map (\t -> near (magnitude (cis t)) 1) [0.5, 2, -1, 4], near (phase (cis 4)) (4 - 2 * pi))
  print (realPart (2 :+ 3 :: Complex Double), imagPart (2 :+ 3 :: Complex Double), imagPart (conjugate (2 :+ 3 :: Complex Double)))
  print (case 5 :+ 6 :: Complex Float of x :+ y -> x + y)
