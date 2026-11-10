-- rows: lib.char.lexlitchar R154
-- Report 19.1 (overlay ov.char.lexlitchar, the lead's ruling 36, R154; M17's bottom probes on the literal Prelude):
-- lexLitChar taking exactly what readLitChar reads; the reference is the printed lexLitChar under another name. They
-- agree on the first and third lines; on the second the printed code takes "\SOHH" and "\Q" whole and "\o" with no
-- digit, and on the last its span looks past "\SOH" into bottom, where the mnemonic matched is all there is to take
-- (R154's differences). A marker, then the terms, the last character by character.
module Main (main) where

import Char

s :: String
s = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (lexLitChar "a b", lexLitChar "\\n x", lexLitChar "\\^A!", lexLitChar "\\123x", lexLitChar "\\x4Fg", lexLitChar "")
  print (lexLitChar "\\SOHH", lexLitChar "\\Q", lexLitChar "\\o", lexLitChar "\\o17")
  print (fst (head (lexLitChar ('x' : s))), fst (head (lexLitChar ("\\n" ++ s))), fst (head (lexLitChar ("\\12" ++ "a" ++ s))))
  mapM_ print (fst (head (lexLitChar ("\\SOH" ++ s))))
