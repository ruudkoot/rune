-- rows: pre.export.maybenothingcjust pre.export.eitherleftcright pre.export.orderingltceqcgt pre.export.char pre.export.string pre.export.int pre.export.integer pre.export.float pre.export.double pre.export.rational pre.export.io pre.export.eqeqeqcslasheq pre.export.ordcomparecltclteqcgteqcgtcmaxcmin pre.export.enumsucccpredctoenumcfromenumcenumfromcenumfromt pre.export.boundedminboundcmaxbound pre.export.numpluscminuscstarcnegatecabscsignumcfrominteger pre.export.realtorational pre.export.integralquotcremcdivcmodcquotremcdivmodctointege pre.export.fractionalslashcrecipcfromrational pre.export.floatingpicexpclogcsqrtcstarstarclogbasecsinccos pre.export.realfracproperfractionctruncatecroundcceilingcfl pre.export.realfloatfloatradixcfloatdigitscfloatrangecdecod pre.export.monadgtgteqcgtgtcreturncfail pre.export.functorfmap pre.export.mapm pre.export.mapmu pre.export.sequence pre.export.sequenceu pre.export.eqltlt pre.export.maybe pre.export.either pre.export.ampamp pre.export.barbar pre.export.not pre.export.otherwise pre.export.subtract pre.export.even pre.export.odd pre.export.gcd pre.export.lcm pre.export.caret pre.export.caretcaret pre.export.fromintegral pre.export.realtofrac pre.export.fst pre.export.snd pre.export.curry pre.export.uncurry pre.export.id pre.export.const pre.export.dot pre.export.flip pre.export.dollar pre.export.until pre.export.astypeof pre.export.error pre.export.undefined pre.export.seq pre.export.dollarbang
-- Report 8: module Prelude exports each of these (types, classes and functions): an explicit import of every one compiles, and each name
-- is used.
module Main (main) where

import Prelude (Bool(False, True), Maybe(Nothing, Just), Either(Left, Right), Ordering(LT, EQ, GT), Char, String, Int, Integer, Float, Double, Rational, IO, Eq((==), (/=)), Ord(compare, (<), (<=), (>=), (>), max, min), Enum(succ, pred, toEnum, fromEnum, enumFrom, enumFromThen, enumFromTo, enumFromThenTo), Bounded(minBound, maxBound), Num((+), (-), (*), negate, abs, signum, fromInteger), Real(toRational), Integral(quot, rem, div, mod, quotRem, divMod, toInteger), Fractional((/), recip, fromRational), Floating(pi, exp, log, sqrt, (**), logBase, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, asinh, acosh, atanh), RealFrac(properFraction, truncate, round, ceiling, floor), RealFloat(floatRadix, floatDigits, floatRange, decodeFloat, encodeFloat, exponent, significand, scaleFloat, isNaN, isInfinite, isDenormalized, isIEEE, isNegativeZero, atan2), Monad((>>=), (>>), return, fail), Functor(fmap), mapM, mapM_, sequence, sequence_, (=<<), maybe, either, (&&), (||), not, otherwise, subtract, even, odd, gcd, lcm, (^), (^^), fromIntegral, realToFrac, fst, snd, curry, uncurry, id, const, (.), flip, ($), until, asTypeOf, error, undefined, seq, ($!), IO, Int, return)

t0 :: Bool -> ()
t0 _ = ()
s0_0 _ = False
s0_1 _ = True

t1 :: Maybe Int -> ()
t1 _ = ()
s1_0 _ = Nothing
s1_1 _ = Just

t2 :: Either Int Int -> ()
t2 _ = ()
s2_0 _ = Left
s2_1 _ = Right

t3 :: Ordering -> ()
t3 _ = ()
s3_0 _ = LT
s3_1 _ = EQ
s3_2 _ = GT

t4 :: Char -> ()
t4 _ = ()

t5 :: String -> ()
t5 _ = ()

t6 :: Int -> ()
t6 _ = ()

t7 :: Integer -> ()
t7 _ = ()

t8 :: Float -> ()
t8 _ = ()

t9 :: Double -> ()
t9 _ = ()

t10 :: Rational -> ()
t10 _ = ()

t11 :: IO Int -> ()
t11 _ = ()

c12 :: (Eq a) => a -> ()
c12 _ = ()
s12_0 _ = (==)
s12_1 _ = (/=)

c13 :: (Ord a) => a -> ()
c13 _ = ()
s13_0 _ = compare
s13_1 _ = (<)
s13_2 _ = (<=)
s13_3 _ = (>=)
s13_4 _ = (>)
s13_5 _ = max
s13_6 _ = min

c14 :: (Enum a) => a -> ()
c14 _ = ()
s14_0 _ = succ
s14_1 _ = pred
s14_2 _ = toEnum
s14_3 _ = fromEnum
s14_4 _ = enumFrom
s14_5 _ = enumFromThen
s14_6 _ = enumFromTo
s14_7 _ = enumFromThenTo

c15 :: (Bounded a) => a -> ()
c15 _ = ()
s15_0 _ = minBound
s15_1 _ = maxBound

c16 :: (Num a) => a -> ()
c16 _ = ()
s16_0 _ = (+)
s16_1 _ = (-)
s16_2 _ = (*)
s16_3 _ = negate
s16_4 _ = abs
s16_5 _ = signum
s16_6 _ = fromInteger

c17 :: (Real a) => a -> ()
c17 _ = ()
s17_0 _ = toRational

c18 :: (Integral a) => a -> ()
c18 _ = ()
s18_0 _ = quot
s18_1 _ = rem
s18_2 _ = div
s18_3 _ = mod
s18_4 _ = quotRem
s18_5 _ = divMod
s18_6 _ = toInteger

c19 :: (Fractional a) => a -> ()
c19 _ = ()
s19_0 _ = (/)
s19_1 _ = recip
s19_2 _ = fromRational

c20 :: (Floating a) => a -> ()
c20 _ = ()
s20_0 _ = pi
s20_1 _ = exp
s20_2 _ = log
s20_3 _ = sqrt
s20_4 _ = (**)
s20_5 _ = logBase
s20_6 _ = sin
s20_7 _ = cos
s20_8 _ = tan
s20_9 _ = asin
s20_10 _ = acos
s20_11 _ = atan
s20_12 _ = sinh
s20_13 _ = cosh
s20_14 _ = tanh
s20_15 _ = asinh
s20_16 _ = acosh
s20_17 _ = atanh

c21 :: (RealFrac a) => a -> ()
c21 _ = ()
s21_0 _ = properFraction
s21_1 _ = truncate
s21_2 _ = round
s21_3 _ = ceiling
s21_4 _ = floor

c22 :: (RealFloat a) => a -> ()
c22 _ = ()
s22_0 _ = floatRadix
s22_1 _ = floatDigits
s22_2 _ = floatRange
s22_3 _ = decodeFloat
s22_4 _ = encodeFloat
s22_5 _ = exponent
s22_6 _ = significand
s22_7 _ = scaleFloat
s22_8 _ = isNaN
s22_9 _ = isInfinite
s22_10 _ = isDenormalized
s22_11 _ = isIEEE
s22_12 _ = isNegativeZero
s22_13 _ = atan2

c23 :: (Monad f) => f a -> ()
c23 _ = ()
s23_0 _ = (>>=)
s23_1 _ = (>>)
s23_2 _ = return
s23_3 _ = fail

c24 :: (Functor f) => f a -> ()
c24 _ = ()
s24_0 _ = fmap

v25 _ = mapM

v26 _ = mapM_

v27 _ = sequence

v28 _ = sequence_

v29 _ = (=<<)

v30 _ = maybe

v31 _ = either

v32 _ = (&&)

v33 _ = (||)

v34 _ = not

v35 _ = otherwise

v36 _ = subtract

v37 _ = even

v38 _ = odd

v39 _ = gcd

v40 _ = lcm

v41 _ = (^)

v42 _ = (^^)

v43 _ = fromIntegral

v44 _ = realToFrac

v45 _ = fst

v46 _ = snd

v47 _ = curry

v48 _ = uncurry

v49 _ = id

v50 _ = const

v51 _ = (.)

v52 _ = flip

v53 _ = ($)

v54 _ = until

v55 _ = asTypeOf

v56 _ = error

v57 _ = undefined

v58 _ = seq

v59 _ = ($!)

main :: IO ()
main = return ()
