-- rows: pre.inst.enumdouble
-- Report 8 (overlay ov.prelude.enumfloat; M17's bottom probes on the literal Prelude): Enum Float's and Enum Double's
-- enumFrom and enumFromThen, the erratum's (e.2003.05.enumstrict: x `seq` numericEnumFrom x); the reference is the
-- printed code, enumFrom = numericEnumFrom, under another name. They agree on every term but the last, where the
-- erratum is strict in x and the printed code gives 1 (the erratum's difference). A marker, then the terms; the last
-- is bottom.
module Main (main) where

u :: Float
u = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (take 3 (enumFrom (1 :: Float)), take 3 (enumFromThen 1 (1.5 :: Double)), take 2 (enumFrom (0.5 :: Double)))
  print (enumFromTo 1 (3 :: Float), enumFromThenTo 1 1.5 (3 :: Double))
  print (length (take 1 (enumFrom u)))
