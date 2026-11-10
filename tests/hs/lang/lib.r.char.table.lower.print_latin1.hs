-- rows: lib.r.char.table.lower.alnum lib.r.char.table.lower.alpha lib.r.char.table.lower.lower lib.r.char.table.other.print lib.r.char.table.other.alnum lib.r.char.table.other.alpha lib.r.char.table.other.upper lib.r.char.table.digit.print lib.r.char.table.digit.alnum lib.r.char.table.printable lib.r.char.table.nonprint lib.r.char.isspace R5 R38 R153
-- Report 19: the table of predicates (isPrint, isAlphaNum, isAlpha, isUpper, isLower) on the Latin-1 characters of each
-- sort: lower case alphabetic (a z e-acute sharp-s y-diaeresis), other alphabetic (A Z E-acute thorn), digits,
-- other printable (+ ~ section times), non-printing (newline DEL PAD NEL APC); and isSpace, true of
-- the seven Latin-1 white characters only.
module Main (main) where

import Char

preds :: [Char -> Bool]
preds = [isPrint, isAlphaNum, isAlpha, isUpper, isLower]

table :: String -> [[Bool]]
table s = [map p s | p <- preds]

main :: IO ()
main = do
  print (table "az\xE9\xDF\xFF")
  print (table "AZ\xC9\xDE")
  print (table "09")
  print (table "+~\xA7\xD7")
  print (table "\n\DEL\x80\x85\x9F")
  print (map isSpace " \t\n\r\f\v\xA0", map isSpace ['\x85', '\x1C', 'a', '\0'])
