-- rows: lib.char.export.islatin1 lib.char.export.iscontrol lib.char.export.isprint lib.char.export.isspace lib.char.export.isupper lib.char.export.islower lib.char.export.isalpha lib.char.export.isdigit lib.char.export.isoctdigit lib.char.export.ishexdigit lib.char.export.isalphanum lib.char.export.digittoint lib.char.export.inttodigit lib.char.export.toupper lib.char.export.tolower lib.char.export.ord lib.char.export.chr lib.char.export.readlitchar lib.char.export.showlitchar lib.char.export.lexlitchar lib.char.export.char lib.char.export.string
-- Report 19: module Char exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Char (isAscii, isLatin1, isControl, isPrint, isSpace, isUpper, isLower, isAlpha, isDigit, isOctDigit, isHexDigit, isAlphaNum, digitToInt, intToDigit, toUpper, toLower, ord, chr, readLitChar, showLitChar, lexLitChar, Char, String)

v0 _ = isAscii

v1 _ = isLatin1

v2 _ = isControl

v3 _ = isPrint

v4 _ = isSpace

v5 _ = isUpper

v6 _ = isLower

v7 _ = isAlpha

v8 _ = isDigit

v9 _ = isOctDigit

v10 _ = isHexDigit

v11 _ = isAlphaNum

v12 _ = digitToInt

v13 _ = intToDigit

v14 _ = toUpper

v15 _ = toLower

v16 _ = ord

v17 _ = chr

v18 _ = readLitChar

v19 _ = showLitChar

v20 _ = lexLitChar

t21 :: Char -> ()
t21 _ = ()

t22 :: String -> ()
t22 _ = ()

main :: IO ()
main = return ()
