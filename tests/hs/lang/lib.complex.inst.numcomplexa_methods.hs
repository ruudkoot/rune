-- rows: lib.complex.inst.fractionalcomplexa lib.complex.inst.floatingcomplexawherepieqpicolonplus0expxcolonplusyeqexpxstarcosycolonplusexpxstarsiny lib.complex.inst.floatingcomplexa lib.complex.inst.eqcomplexa lib.complex.inst.readcomplexa lib.complex.inst.showcomplexa lib.r.complex.abs lib.r.complex.signum.zero lib.r.complex.signum lib.r.complex.show R49
-- Report 13.1: the instances of Complex a, each method on samples against the Report's own code copied under new names,
-- to a tolerance (a method's copy calls the instance's other methods, each checked here too): abs z is
-- magnitude z :+ 0, signum 0 is 0 and signum z of magnitude 1 and z's phase; Eq, Read and Show derived, Show at
-- infix 6. A negative component's show waits for R42 and is not shown here.
module Main (main) where

import Complex

near :: Double -> Double -> Bool
near a b = abs (a - b) <= 1.0e-12 * maximum [1, abs a, abs b]

nearC :: Complex Double -> Complex Double -> Bool
nearC (a :+ b) (c :+ d) = near a c && near b d

exp', log', sqrt', sin', cos', tan', sinh', cosh', tanh', asin', acos', atan', asinh', acosh', atanh' :: Complex Double -> Complex Double
exp' (x :+ y) = expx * cos y :+ expx * sin y
  where expx = exp x
log' z = log (magnitude z) :+ phase z
sqrt' 0 = 0
sqrt' z@(x :+ y) = u :+ (if y < 0 then - v else v)
  where (u, v) = if x < 0 then (v'', u'') else (u'', v'')
        v'' = abs y / (u'' * 2)
        u'' = sqrt ((magnitude z + abs x) / 2)
sin' (x :+ y) = sin x * cosh y :+ cos x * sinh y
cos' (x :+ y) = cos x * cosh y :+ (- sin x * sinh y)
tan' (x :+ y) = (sinx * coshy :+ cosx * sinhy) / (cosx * coshy :+ (- sinx * sinhy))
  where sinx = sin x
        cosx = cos x
        sinhy = sinh y
        coshy = cosh y
sinh' (x :+ y) = cos y * sinh x :+ sin y * cosh x
cosh' (x :+ y) = cos y * cosh x :+ sin y * sinh x
tanh' (x :+ y) = (cosy * sinhx :+ siny * coshx) / (cosy * coshx :+ siny * sinhx)
  where siny = sin y
        cosy = cos y
        sinhx = sinh x
        coshx = cosh x
asin' z@(x :+ y) = y' :+ (- x')
  where (x' :+ y') = log (((- y) :+ x) + sqrt (1 - z * z))
acos' z@(x :+ y) = y'' :+ (- x'')
  where (x'' :+ y'') = log (z + ((- y') :+ x'))
        (x' :+ y') = sqrt (1 - z * z)
atan' z@(x :+ y) = y' :+ (- x')
  where (x' :+ y') = log (((1 - y) :+ x) / sqrt (1 + z * z))
asinh' z = log (z + sqrt (1 + z * z))
acosh' z = log (z + (z + 1) * sqrt ((z - 1) / (z + 1)))
atanh' z = log ((1 + z) / sqrt (1 - z * z))

divide' :: Complex Double -> Complex Double -> Complex Double
divide' (x :+ y) (x' :+ y') = (x * x'' + y * y'') / d :+ (y * x'' - x * y'') / d
  where x'' = scaleFloat k x'
        y'' = scaleFloat k y'
        k = - max (exponent x') (exponent y')
        d = x' * x'' + y' * y''

signum' :: Complex Double -> Complex Double
signum' 0 = 0
signum' z@(x :+ y) = x / r :+ y / r
  where r = magnitude z

ws :: [Complex Double]
ws = [0.5 :+ 0.25, (-1.5) :+ 0.75, 2 :+ (-1), (-0.3) :+ (-0.6), 3 :+ 4]

main :: IO ()
main = do
  print [nearC (a + b) ((realPart a + realPart b) :+ (imagPart a + imagPart b)) && nearC (a - b) ((realPart a - realPart b) :+ (imagPart a - imagPart b)) | a <- ws, b <- ws]
  print [nearC (a * b) ((realPart a * realPart b - imagPart a * imagPart b) :+ (realPart a * imagPart b + imagPart a * realPart b)) | a <- ws, b <- ws]
  print [nearC (negate a) (negate (realPart a) :+ negate (imagPart a)) && nearC (abs a) (magnitude a :+ 0) && nearC (signum a) (signum' a) | a <- ws]
  print (signum (0 :: Complex Double), fromInteger 3 :: Complex Double, abs (3 :+ 4 :: Complex Double), map (near 1 . magnitude . signum) ws, and [near (phase (signum a)) (phase a) | a <- ws])
  print [nearC (a / b) (divide' a b) | a <- ws, b <- ws]
  print (fromRational 2.5 :: Complex Double, recip (2 :+ 0 :: Complex Double), (1 :+ 2) / (1.0e300 :+ 1.0e300) /= 0)
  print (pi :: Complex Double)
  print [and [nearC (f a) (g a) | a <- ws] | (f, g) <- [(exp, exp'), (log, log'), (sqrt, sqrt'), (sin, sin'), (cos, cos'), (tan, tan'), (sinh, sinh'), (cosh, cosh'), (tanh, tanh')]]
  print [and [nearC (f a) (g a) | a <- ws] | (f, g) <- [(asin, asin'), (acos, acos'), (atan, atan'), (asinh, asinh'), (acosh, acosh'), (atanh, atanh')]]
  print (sqrt (0 :: Complex Double), sqrt ((-4) :+ 0 :: Complex Double), sqrt (0 :+ 2 :: Complex Double))
  print (nearC (2 ** (3 :+ 0)) (8 :+ 0), nearC (logBase 2 (8 :+ 0)) (3 :+ 0), nearC (sqrt (4 :+ 0)) (2 :+ 0))
  print ((1 :+ 2) == (1 :+ 2 :: Complex Double), (1 :+ 2) /= (1 :+ 2.5 :: Complex Double))
  print (read "1.5 :+ 2.0" :: Complex Double, read "(3 :+ 4)" :: Complex Double, imagPart (read " 0.5 :+ (-1)" :: Complex Double))
  putStrLn (show (1.5 :+ 2 :: Complex Double))
  putStrLn (showsPrec 7 (1.5 :+ 2 :: Complex Double) "")
  print (Just (0.5 :+ 1 :: Complex Float))
