-- rows: lib.r.numeric.showintatbase lib.r.numeric.showint lib.r.numeric.showoct lib.r.numeric.showhex lib.r.numeric.showffloat lib.r.numeric.showefloat lib.r.numeric.showgfloat.mid lib.r.numeric.showgfloat.out lib.r.numeric.digs.nothing lib.r.numeric.digs.just lib.r.numeric.signed.float lib.r.numeric.floattodigits.value lib.r.numeric.floattodigits.n lib.r.numeric.floattodigits.d1 lib.r.numeric.floattodigits.range lib.r.numeric.readsigned lib.r.numeric.readint lib.r.numeric.readfloat lib.r.numeric.readdec lib.r.numeric.readoct lib.r.numeric.readhex lib.r.numeric.lexdigits lib.r.numeric.fromrat lib.r.numeric.floattodigits.shortest R49 R150 R151
-- Report 14.1 to 14.4: the text's statements of Numeric, each on its example: showSigned parenthesises above 6, the
-- bases, the three float formats and their precision, negative values, floatToDigits's properties (r = 0.d1...dn * b^e exactly in bases 2 and 16, and in base 10 to the
-- nearest float, readings.md R151), the readers, and fromRat correctly rounded. The expected output is
-- the Report's code's; showFFloat Nothing 245000 is 245000.0 by the code, where the prose says 245000
-- (readings.md R150).
module Main (main) where

import Char
import Ratio
import Numeric

main :: IO ()
main = do
  print (showSigned showInt 7 (-3 :: Int) "", showSigned showInt 6 (-3 :: Int) "", showSigned showInt 7 (3 :: Int) "")
  print (showIntAtBase 2 intToDigit (5 :: Int) "", showInt (123 :: Integer) "", showOct (64 :: Int) "", showHex (255 :: Integer) "", showHex (3054 :: Int) "")
  print (showFFloat Nothing (245000 :: Double) "", showFFloat Nothing (0.0015 :: Double) "")
  print (showEFloat Nothing (245 :: Double) "", showEFloat Nothing (0.0015 :: Double) "")
  print (showGFloat Nothing (0.1 :: Double) "", showGFloat Nothing (9999999 :: Double) "", showGFloat Nothing (0.09 :: Double) "", showGFloat Nothing (1.0e7 :: Double) "")
  print (showEFloat Nothing (1 / 3 :: Double) "", showFFloat Nothing (1 / 3 :: Double) "", showGFloat Nothing (1 / 3 :: Double) "")
  print (showEFloat (Just 2) (1234.5678 :: Double) "", showFFloat (Just 2) (1234.5678 :: Double) "", showGFloat (Just 2) (1234.5678 :: Double) "")
  print (floatToDigits 10 (0.1 :: Double), floatToDigits 2 (0.75 :: Double), floatToDigits 16 (255 :: Float))
  print ([rebuild b x == toRational x | b <- [2, 16], x <- xs], [fromRational (rebuild 10 x) == x | x <- take 2 xs ++ drop 4 xs], map (rebuild 10) [0.1, 3.5 :: Double])
  print [let (dss, _) = floatToDigits b x in (length dss >= 0, null dss || head dss /= 0, all (\d -> d >= 0 && toInteger d <= b - 1) dss) | b <- [2, 10, 16], x <- [0.1, 7, 5.0e-324 :: Double]]
  print (show (0.1 :: Double), show (0.1 :: Float), show (1.0e-2 :: Double))
  print (readSigned readDec "-3 x" :: [(Integer, String)], readInt 3 (`elem` "012") digitToInt "1201 z" :: [(Integer, String)])
  print (readFloat "1.5e2" :: [(Double, String)], readFloat "2" :: [(Double, String)], readFloat "1e3" :: [(Double, String)])
  print (readDec "123" :: [(Int, String)], readOct "17" :: [(Int, String)], readHex "ff" :: [(Int, String)], readHex "FF" :: [(Int, String)])
  print (lexDigits "x", lexDigits "12ab", showFFloat Nothing (-1.5 :: Double) "", showEFloat (Just 2) (-1234.5 :: Double) "")
  print ((fromRat (1 % 3) :: Double) == 1 / 3, (fromRat (1 % 3) :: Float) == 1 / 3, (fromRat (-5 % 7) :: Double) == -5 / 7)
  where xs = [0.1, 3.5, 1.0e-300, 5.0e-324, 123456.789 :: Double]
        rebuild :: Integer -> Double -> Rational
        rebuild b x = let (dss, e) = floatToDigits b x in foldr (\d acc -> (fromIntegral d + acc) / fromInteger b) 0 dss * fromInteger b ^^ e
