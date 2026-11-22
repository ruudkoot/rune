-- rows: pre.text.inst.showfloat
-- Report 8.2, 10.4 (overlay ov.preludetext.showfloat, the lead's ruling R42; M17's bottom probes on the literal
-- Prelude): Show Float's and Show Double's showsPrec p = showSigned showFloat p; the reference is the printed
-- showsPrec p = showFloat under another name. They agree on every term but the first line's second, fourth and fifth,
-- where the printed code gives -1.5, -2.5 and Just -2.0 (R42's difference). A marker, then the terms; the last is
-- bottom.
module Main (main) where

d :: Double
d = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (showsPrec 6 (-1.5 :: Double) "", showsPrec 7 (-1.5 :: Double) "", showsPrec 7 (1.5 :: Float) "",
         showsPrec 11 (-2.5 :: Float) "", show (Just (-2.0 :: Double)))
  print (showsPrec 7 (-0.0 :: Double) "", show (1.0e-2 :: Double), show (1.0e7 :: Float), take 0 (showsPrec 7 d ""))
  print (length (showsPrec 7 d ""))
