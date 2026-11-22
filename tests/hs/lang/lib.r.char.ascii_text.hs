-- rows: lib.r.char.latin1 lib.r.char.isdigit lib.r.char.isoctdigit lib.r.char.ishexdigit lib.r.char.digittoint lib.r.char.inttodigit lib.r.char.ord lib.r.char.chr lib.r.char.iscontrol lib.r.char.isascii lib.r.char.showlitchar lib.r.char.showlitchar.example lib.r.char.lexlitchar lib.r.char.lexlitchar.example lib.r.char.readlitchar lib.r.char.readlitchar.example lib.r.char.protectesc lib.r.char.toupper lib.r.char.tolower R154
-- Report 19: the first 128 characters are ASCII and the next 128 Latin-1; isDigit, isOctDigit and isHexDigit select ASCII;
-- digitToInt of either case and intToDigit in lower case; ord and chr are fromEnum and toEnum; isControl, isAscii
-- and isLatin1 by the code; showLitChar in printable characters and source escapes, protecting a digit after a
-- numeric escape and H after \SO with \&; the text's three examples of showLitChar, lexLitChar and readLitChar;
-- toUpper and toLower on Latin-1 letters, leaving the rest. The expected output is the Report's code's.
module Main (main) where

import Char

main :: IO ()
main = do
  print (map fromEnum "AZaz09 ~", fromEnum '\DEL', fromEnum '\NUL', toEnum 65 :: Char, ['\x41', '\o101', '\65'])
  print (fromEnum '\xE9', fromEnum '\255', toEnum 233 :: Char, '\xE9' == '\233')
  print (filter isDigit cs, filter isOctDigit cs, filter isHexDigit cs)
  print (map digitToInt "0123456789abcdefABCDEF")
  print (map intToDigit [0 .. 15])
  print (map ord "a\0\255", map chr [97, 0, 255], and [ord c == fromEnum c | c <- cs], and [chr i == toEnum i | i <- [0 .. 255]])
  print (map fromEnum (filter isControl cs))
  print (length (filter isAscii cs), length (filter isLatin1 cs), map isAscii "\x7F\x80", map isLatin1 "\xFE\xFF")
  putStrLn (concatMap (\c -> showLitChar c "") cs)
  putStrLn (showLitChar '\200' (showLitChar '5' (showLitChar '\SO' (showLitChar 'H' ""))))
  print (showLitChar '\n' "s", showLitChar '\n' "s" == "\\n" ++ "s")
  print (lexLitChar "\\nHello", lexLitChar "\\nHello" == [("\\n", "Hello")], lexLitChar "a")
  print (lexLitChar "\\x41z", lexLitChar "\\SOH", lexLitChar "\\^Ax")
  print (readLitChar "\\nHello", readLitChar "\\nHello" == [('\n', "Hello")], readLitChar "\\x41z", readLitChar "\\SOH", readLitChar "\\SOx")
  print (readLitChar "\\^Ax", readLitChar "\\65", readLitChar "\\o101", readLitChar "\\DEL", readLitChar "\\SP")
  print (show "\200\&5", read (show "\200\&5") == "\200\&5", show "\SO\&H", read (show "\SO\&H") == "\SO\&H", show "\SOH")
  print (map toUpper "abz09 \xE9\xE0", map toLower "ABZ09 \xC9\xC0", toUpper '\xDF', toLower '\xD7')
  where cs = ['\0' .. '\255']
