-- rows: lib.r.char.table.other.print lib.r.char.table.other.alnum lib.r.char.table.other.alpha lib.r.char.table.lower.print lib.r.char.table.lower.alnum lib.r.char.table.lower.alpha lib.r.char.table.lower.lower lib.r.char.table.digit.print lib.r.char.table.digit.alnum lib.r.char.table.printable lib.r.char.table.nonprint lib.r.char.isspace lib.r.char.toupper.unicode lib.r.char.toupper lib.r.char.tolower lib.r.char.digitreader lib.r.char.isalpha lib.r.char.isascii lib.r.char.showlitchar lib.r.char.protectesc lib.char.isprint.def lib.char.isupper.def lib.char.islower.def lib.char.isalpha.def lib.char.isalphanum.def lib.char.toupper lib.char.tolower R5 R38 R153 R6
-- Report 19: the table beyond Latin-1, on characters whose category has stood since Unicode 3.0 (readings.md R153): a
-- title-case letter, a letter of no case and a CJK ideograph are other alphabetic, so upper case ("any alphabetic
-- character which is not lower case is treated as upper case"); Greek and Latin Extended letters; non-ASCII digits
-- (isAlphaNum, not isAlpha, not isDigit, and not read as numbers); symbols; a line separator and a format
-- character, non-printing; toUpper and toLower of any letter with an equivalent; isSpace false beyond Latin-1;
-- showLitChar's decimal escapes; and isAlpha c == isUpper c || isLower c at every character. The expected output
-- is written from the text.
module Main (main) where

import Char

preds :: [Char -> Bool]
preds = [isPrint, isAlphaNum, isAlpha, isUpper, isLower]

table :: String -> [[Bool]]
table s = [map p s | p <- preds]

main :: IO ()
main = do
  print (table "\x1C5\x5D0\x4E2D")
  print (table "\x3C9\x3B1\x101")
  print (table "\x3A9\x100")
  print (table "\x661\x967")
  print (table "\x20AC\x2200")
  print (table "\x2028\x200E")
  print (map toUpper "\x3C9\x101\xFF\xB5\x1C5\x4E2D", map toLower "\x3A9\x100\x1C5\x4E2D")
  print (map isSpace "\x2003\x3000\x2028", isSpace '\xA0')
  print (reads "\x661" :: [(Int, String)], reads "1\x661" :: [(Int, String)], isDigit '\x661', isHexDigit '\xFF21')
  print (isLatin1 '\x100', isAscii '\x100', isControl '\x100', ord '\x4E2D', chr 20013 == '\x4E2D')
  putStrLn (concatMap (\c -> showLitChar c "") ['\256' .. '\299'] ++ showLitChar '\x4E2D' "")
  print (show "\1234\&5", read (show "\1234\&5") == "\1234\&5", lexLitChar "\\1234x", readLitChar "\\x4E2Dz")
  print (and [isAlpha c == (isUpper c || isLower c) | c <- [minBound .. maxBound]])
