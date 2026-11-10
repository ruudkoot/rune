-- rows: lib.numeric.showint lib.numeric.showoct lib.numeric.showhex lib.numeric.showintatbase lib.numeric.readsigned lib.numeric.readint lib.numeric.readdec lib.numeric.readoct lib.numeric.readhex lib.numeric.showefloat lib.numeric.showffloat lib.numeric.showgfloat lib.numeric.showfloat lib.numeric.formatrealfloat lib.numeric.roundto lib.numeric.floattodigits lib.numeric.readfloat lib.numeric.lexdigits lib.numeric.nonnull lib.numeric.fromrat lib.numeric.fromratp lib.numeric.scalerat lib.numeric.minexpt.def lib.numeric.maxexpt.def lib.numeric.expt lib.numeric.expts lib.numeric.integerlogbase lib.numeric.data.ffformat
-- Report 14: each function of Numeric against the Report's own module copied under new names (its hidden helpers and
-- FFFormat with it), on samples: integers in several bases, readers on good and bad input, floatToDigits in bases
-- 2, 10 and 16 at Double and Float (denormals and extremes too), the three float formats with every precision,
-- negatives, -0, NaN and the infinities, and fromRat at both types.
module Main (main) where

import Numeric
import Char
import Ratio
import Array

-- This converts a rational to a floating.  This should be used in the
-- Fractional instances of Float and Double.

fromRat_r :: (RealFloat a) => Rational -> a
fromRat_r x =
    if x == 0 then encodeFloat 0 0              -- Handle exceptional cases
    else if x < 0 then - fromRat'_r (-x)          -- first.
    else fromRat'_r x

-- Conversion process:
-- Scale the rational number by the RealFloat base until
-- it lies in the range of the mantissa (as used by decodeFloat/encodeFloat).
-- Then round the rational to an Integer and encode it with the exponent
-- that we got from the scaling.
-- To speed up the scaling process we compute the log2 of the number to get
-- a first guess of the exponent.
fromRat'_r :: (RealFloat a) => Rational -> a
fromRat'_r x = r
  where b = floatRadix r
        p = floatDigits r
        (minExp0, _) = floatRange r
        minExp = minExp0 - p            -- the real minimum exponent
        xMin = toRational (expt_r b (p-1))
        xMax = toRational (expt_r b p)
        p0 = (integerLogBase_r b (numerator x) -
              integerLogBase_r b (denominator x) - p) `max` minExp
        f = if p0 < 0 then 1 % expt_r b (-p0) else expt_r b p0 % 1
        (x', p') = scaleRat_r (toRational b) minExp xMin xMax p0 (x / f)
        r = encodeFloat (round x') p'

-- Scale x until xMin <= x < xMax, or p (the exponent) <= minExp.
scaleRat_r :: Rational -> Int -> Rational -> Rational ->
             Int -> Rational -> (Rational, Int)
scaleRat_r b minExp xMin xMax p x =
    if p <= minExp then
        (x, p)
    else if x >= xMax then
        scaleRat_r b minExp xMin xMax (p+1) (x/b)
    else if x < xMin  then
        scaleRat_r b minExp xMin xMax (p-1) (x*b)
    else
        (x, p)

-- Exponentiation with a cache for the most common numbers.
minExpt_r = 0::Int
maxExpt_r = 1100::Int
expt_r :: Integer -> Int -> Integer
expt_r base n =
    if base == 2 && n >= minExpt_r && n <= maxExpt_r then
        expts_r!n
    else
        base^n

expts_r :: Array Int Integer
expts_r = array (minExpt_r,maxExpt_r) [(n,2^n) | n <- [minExpt_r .. maxExpt_r]]

-- Compute the (floor of the) log of i in base b.
-- Simplest way would be just divide i by b until it's smaller then b,
-- but that would be very slow!  We are just slightly more clever.
integerLogBase_r :: Integer -> Integer -> Int
integerLogBase_r b i =
     if i < b then
        0
     else
        -- Try squaring the base first to cut down the number of divisions.
        let l = 2 * integerLogBase_r (b*b) i
            doDiv :: Integer -> Int -> Int
            doDiv i l = if i < b then l else doDiv (i `div` b) (l+1)
        in  doDiv (i `div` (b^l)) l


-- Misc utilities to show integers and floats

showSigned_r :: Real a => (a -> ShowS) -> Int -> a -> ShowS
showSigned_r showPos p x
  | x < 0     = showParen (p > 6) (showChar '-' . showPos (-x))
  | otherwise = showPos x

-- showInt_r, showOct_r, showHex_r are used for positive numbers only
showInt_r, showOct_r, showHex_r :: Integral a => a -> ShowS
showOct_r = showIntAtBase_r  8 intToDigit
showInt_r = showIntAtBase_r 10 intToDigit
showHex_r = showIntAtBase_r 16 intToDigit

showIntAtBase_r :: Integral a
              => a              -- base
              -> (Int -> Char)  -- digit to char
              -> a              -- number to show
              -> ShowS
showIntAtBase_r base intToDig n rest
  | n < 0     = error "Numeric.showIntAtBase_r: can't show negative numbers"
  | n' == 0   = rest'
  | otherwise = showIntAtBase_r base intToDig n' rest'
  where
    (n',d) = quotRem n base
    rest'  = intToDig (fromIntegral d) : rest


readSigned_r :: (Real a) => ReadS a -> ReadS a
readSigned_r readPos = readParen False read'
                     where read' r  = read'' r ++
                                      [(-x,t) | ("-",s) <- lex r,
                                                (x,t)   <- read'' s]
                           read'' r = [(n,s)  | (str,s) <- lex r,
                                                (n,"")  <- readPos str]


-- readInt_r reads a string of digits using an arbitrary base.
-- Leading minus signs must be handled elsewhere.

readInt_r :: (Integral a) => a -> (Char -> Bool) -> (Char -> Int) -> ReadS a
readInt_r radix isDig digToInt s =
   [(foldl1 (\n d -> n * radix + d) (map (fromIntegral . digToInt) ds), r)
          | (ds,r) <- nonnull_r isDig s ]

-- Unsigned readers for various bases
readDec_r, readOct_r, readHex_r :: (Integral a) => ReadS a
readDec_r = readInt_r 10 isDigit    digitToInt
readOct_r = readInt_r  8 isOctDigit digitToInt
readHex_r = readInt_r 16 isHexDigit digitToInt


showEFloat_r     :: (RealFloat a) => Maybe Int -> a -> ShowS
showFFloat_r     :: (RealFloat a) => Maybe Int -> a -> ShowS
showGFloat_r     :: (RealFloat a) => Maybe Int -> a -> ShowS
showFloat_r      :: (RealFloat a) => a -> ShowS

showEFloat_r d x =  showString (formatRealFloat_r FFExponent_r d x)
showFFloat_r d x =  showString (formatRealFloat_r FFFixed_r d x)
showGFloat_r d x =  showString (formatRealFloat_r FFGeneric_r d x)
showFloat_r      =  showGFloat_r Nothing

-- These are the format types.  This type is not exported.

data FFFormat_r = FFExponent_r | FFFixed_r | FFGeneric_r

formatRealFloat_r :: (RealFloat a) => FFFormat_r -> Maybe Int -> a -> String
formatRealFloat_r fmt decs x
  = s
  where
    base = 10
    s = if isNaN x then
            "NaN"
        else if isInfinite x then
            if x < 0 then "-Infinity" else "Infinity"
        else if x < 0 || isNegativeZero x then
            '-' : doFmt fmt (floatToDigits_r (toInteger base) (-x))
        else
            doFmt fmt (floatToDigits_r (toInteger base) x)

    doFmt fmt (is, e)
      = let
           ds = map intToDigit is
        in
        case fmt of
          FFGeneric_r ->
              doFmt (if e < 0 || e > 7 then FFExponent_r else FFFixed_r)
                    (is, e)
          FFExponent_r ->
            case decs of
              Nothing ->
                case ds of
                   []    -> "0.0e0"
                   [d]   -> d : ".0e" ++ show (e-1)
                   d:ds  -> d : '.' : ds ++ 'e':show (e-1)

              Just dec ->
                let dec' = max dec 1 in
                case is of
                  [] -> '0':'.':take dec' (repeat '0') ++ "e0"
                  _ ->
                    let (ei, is') = roundTo_r base (dec'+1) is
                        d:ds = map intToDigit
                                   (if ei > 0 then init is' else is')
                    in d:'.':ds  ++ "e" ++ show (e-1+ei)

          FFFixed_r ->
            case decs of
               Nothing         -- Always prints a decimal point
                 | e > 0     -> take e (ds ++ repeat '0')
                                ++ '.' : mk0 (drop e ds)
                 | otherwise -> "0." ++ mk0 (replicate (-e) '0' ++ ds)

               Just dec ->  -- Print decimal point iff dec > 0
                 let dec' = max dec 0 in
                 if e >= 0 then
                   let (ei, is') = roundTo_r base (dec' + e) is
                       (ls, rs)  = splitAt (e+ei)
                                              (map intToDigit is')
                   in  mk0 ls ++ mkdot0 rs
                 else
                   let (ei, is') = roundTo_r base dec'
                                           (replicate (-e) 0 ++ is)
                       d : ds = map intToDigit
                                    (if ei > 0 then is' else 0:is')
                   in  d : mkdot0 ds
            where
              mk0 "" = "0"        -- Print 0.34, not .34
              mk0 s  = s

              mkdot0 "" = ""       -- Print 34, not 34.
              mkdot0 s  = '.' : s  -- when the format specifies no
                                   -- digits after the decimal point


roundTo_r :: Int -> Int -> [Int] -> (Int, [Int])
roundTo_r base d is = case f d is of
                (0, is) -> (0, is)
                (1, is) -> (1, 1 : is)
  where b2 = base `div` 2
        f n [] = (0, replicate n 0)
        f 0 (i:_) = (if i >= b2 then 1 else 0, [])
        f d (i:is) =
            let (c, ds) = f (d-1) is
                i' = c + i
            in  if i' == base then (1, 0:ds) else (0, i':ds)

--
-- Based on "Printing Floating-Point Numbers Quickly and Accurately"
-- by R.G. Burger and R. K. Dybvig, in PLDI 96.
-- The version here uses a much slower logarithm estimator.
-- It should be improved.

-- This function returns a non-empty list of digits (Ints in [0..base-1])
-- and an exponent.  In general, if
--      floatToDigits_r r = ([a, b, ... z], e)
-- then
--      r = 0.ab..z * base^e
--

floatToDigits_r :: (RealFloat a) => Integer -> a -> ([Int], Int)

floatToDigits_r _ 0 = ([], 0)
floatToDigits_r base x =
    let (f0, e0) = decodeFloat x
        (minExp0, _) = floatRange x
        p = floatDigits x
        b = floatRadix x
        minExp = minExp0 - p            -- the real minimum exponent

        -- Haskell requires that f be adjusted so denormalized numbers
        -- will have an impossibly low exponent.  Adjust for this.
        f :: Integer
        e :: Int
        (f, e) = let n = minExp - e0
                 in  if n > 0 then (f0 `div` (b^n), e0+n) else (f0, e0)

        (r, s, mUp, mDn) =
           if e >= 0 then
               let be = b^e in
               if f == b^(p-1) then
                   (f*be*b*2, 2*b, be*b, b)
               else
                   (f*be*2, 2, be, be)
           else
               if e > minExp && f == b^(p-1) then
                   (f*b*2, b^(-e+1)*2, b, 1)
               else
                   (f*2, b^(-e)*2, 1, 1)
        k =
            let k0 =
                    if b==2 && base==10 then
                        -- logBase 10 2 is slightly bigger than 3/10 so
                        -- the following will err on the low side.  Ignoring
                        -- the fraction will make it err even more.
                        -- Haskell promises that p-1 <= logBase b f < p.
                        (p - 1 + e0) * 3 `div` 10
                    else
                        ceiling ((log (fromInteger (f+1)) +
                                 fromIntegral e * log (fromInteger b)) /
                                  log (fromInteger base))
                fixup n =
                    if n >= 0 then
                        if r + mUp <= expt_r base n * s then n else fixup (n+1)
                    else
                        if expt_r base (-n) * (r + mUp) <= s then n
                                                           else fixup (n+1)
            in  fixup k0

        gen ds rn sN mUpN mDnN =
            let (dn, rn') = (rn * base) `divMod` sN
                mUpN' = mUpN * base
                mDnN' = mDnN * base
            in  case (rn' < mDnN', rn' + mUpN' > sN) of
                (True,  False) -> dn : ds
                (False, True)  -> dn+1 : ds
                (True,  True)  -> if rn' * 2 < sN then dn : ds else dn+1 : ds
                (False, False) -> gen (dn:ds) rn' sN mUpN' mDnN'
        rds =
            if k >= 0 then
                gen [] r (s * expt_r base k) mUp mDn
            else
                let bk = expt_r base (-k)
                in  gen [] (r * bk) s (mUp * bk) (mDn * bk)
    in  (map fromIntegral (reverse rds), k)



-- This floating point reader uses a less restrictive syntax for floating
-- point than the Haskell lexer.  The `.' is optional.

readFloat_r     :: (RealFrac a) => ReadS a
readFloat_r r    = [(fromRational ((n%1)*10^^(k-d)),t) | (n,d,s) <- readFix r,
                                                       (k,t)   <- readExp s] ++
                 [ (0/0, t) | ("NaN",t)      <- lex r] ++
                 [ (1/0, t) | ("Infinity",t) <- lex r]
               where
                 readFix r = [(read (ds++ds'), length ds', t)
                             | (ds,d) <- lexDigits_r r,
                               (ds',t) <- lexFrac d ]

                 lexFrac ('.':ds) = lexDigits_r ds
                 lexFrac s        = [("",s)]

                 readExp (e:s) | e `elem` "eE" = readExp' s
                 readExp s                     = [(0,s)]

                 readExp' ('-':s) = [(-k,t) | (k,t) <- readDec_r s]
                 readExp' ('+':s) = readDec_r s
                 readExp' s       = readDec_r s

lexDigits_r        :: ReadS String
lexDigits_r        =  nonnull_r isDigit

nonnull_r          :: (Char -> Bool) -> ReadS String
nonnull_r p s      =  [(cs,t) | (cs@(_:_),t) <- [span p s]]

ds :: [Double]
ds = [0.1, 1, 123.456, 1.0e-300, 5.0e-324, 1.7976931348623157e308, pi, 245100, 0.0015, 1 / 3, 9999999, 1.0e7, 0.09]

fs :: [Float]
fs = [0.1, 1, 123.456, 1.0e-40, 3.4028235e38, pi, 1 / 3]

ns :: [Integer]
ns = [0, 1, 5, 7, 255, 1000, 123456789012345678901234567890]

negs :: [Double]
negs = [-1.5, -245100, -0.0015]

digs :: [Maybe Int]
digs = [Nothing, Just 1, Just 2, Just 5]

same :: (Eq a) => [a] -> [a] -> Bool
same xs ys = and (zipWith (==) xs ys) && length xs == length ys

main :: IO ()
main = do
  print [showSigned showInt p x "" == showSigned_r showInt_r p x "" | p <- [0, 6, 7], x <- [-3, 0, 5 :: Integer]]
  print [showIntAtBase b intToDigit n "!" == showIntAtBase_r b intToDigit n "!" | b <- [2, 3, 8, 10, 16], n <- ns]
  print [(showInt n "", showOct n "", showHex n "") == (showInt_r n "", showOct_r n "", showHex_r n "") | n <- ns]
  print [(showInt n "", showHex n "") == (showInt_r n "", showHex_r n "") | n <- [0, 9, 10, 2147483647 :: Int]]
  print [same (readSigned readDec s :: [(Integer, String)]) (readSigned_r readDec_r s) | s <- ["-3 x", "3", "(-4)", " - 5", "(7) rest", "x"]]
  print [same (readInt 3 (`elem` "012") digitToInt s :: [(Integer, String)]) (readInt_r 3 (`elem` "012") digitToInt s) | s <- ["1201 z", "3", "", "0"]]
  print [same (readDec s :: [(Integer, String)]) (readDec_r s) && same (readOct s :: [(Integer, String)]) (readOct_r s) && same (readHex s :: [(Integer, String)]) (readHex_r s) | s <- ["123", "777", "ff", "FF", "12a", "", "x9"]]
  print [floatToDigits b x == floatToDigits_r b x | b <- [2, 10, 16], x <- ds]
  print [floatToDigits b x == floatToDigits_r b x | b <- [2, 10, 16], x <- fs]
  print [(showEFloat d x "", showFFloat d x "", showGFloat d x "") == (showEFloat_r d x "", showFFloat_r d x "", showGFloat_r d x "") | d <- digs, x <- ds]
  print [(showEFloat d x "", showFFloat d x "", showGFloat d x "") == (showEFloat_r d x "", showFFloat_r d x "", showGFloat_r d x "") | d <- digs, x <- fs]
  print [showFloat x "" == showFloat_r x "" | x <- ds ++ negs]
  print [(showEFloat d x "", showFFloat d x "", showGFloat d x "") == (showEFloat_r d x "", showFFloat_r d x "", showGFloat_r d x "") | d <- digs, x <- negs]
  print [map fst (readFloat s :: [(Double, String)]) == map fst (readFloat_r s) && map snd (readFloat s :: [(Double, String)]) == map snd (readFloat_r s :: [(Double, String)]) | s <- ["1.5e2", "2", "1e3", "12.5x", "1e-2", "0.25E+1", ".5", "x"]]
  print [same (lexDigits s) (lexDigits_r s) && same (lexDigits s) (nonnull_r isDigit s) | s <- ["123ab", "x", "", "9"]]
  print [(fromRat r :: Double) == fromRat_r r && (fromRat r :: Float) == fromRat_r r | r <- [0, 1 % 3, 2 % 3, -5 % 7, 1 % 10, 123456789 % 1000, 1 % (2 ^ 1074), 2 ^ 1023 * 3 % 2]]
  print (expt_r 2 10, expt_r 10 3, integerLogBase_r 10 12345, integerLogBase_r 2 1024)
  print (minExpt_r, maxExpt_r, expts_r ! 64)
  print (scaleRat_r 2 (-1074) (2 ^ 52) (2 ^ 53) 0 (3 % 2), fromRat'_r (1 % 3) == (1 / 3 :: Double), [FFExponent_r, FFFixed_r, FFGeneric_r] `seq` ())
