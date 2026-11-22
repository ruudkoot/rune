module Char (
    isAscii, isLatin1, isControl, isPrint, isSpace, isUpper, isLower,
    isAlpha, isDigit, isOctDigit, isHexDigit, isAlphaNum,
    digitToInt, intToDigit, toUpper, toLower, ord, chr,
    readLitChar, showLitChar, lexLitChar,
    Char, String
  ) where
import Data.Char
import Numeric (readDec)
readLitChar :: ReadS Char
readLitChar (c:s) | c /= '\\' = [(c,s)]
readLitChar s = [ (x, r) | (x, r) <- reads ('\'':take 1 s ++ "'") ]
lexLitChar :: ReadS String
lexLitChar (c:s) = [([c],s)]
lexLitChar [] = []
showLitChar :: Char -> ShowS
showLitChar c s = init (tail (show c)) ++ s
