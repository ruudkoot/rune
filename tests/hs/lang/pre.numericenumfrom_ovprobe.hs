-- rows: pre.numericenumfromthen pre.numericenumfromto pre.numericenumfromthento
-- Report 8, 12 (overlay ov.prelude.numericenum; M17's bottom probes on the literal Prelude): the four numericEnum*,
-- moved to rhc's PreludeEnum with their 14 lines as printed, through Ratio's Enum and Float's and Double's; the
-- reference is those lines copied under other names. A marker, then the terms; the last is bottom.
module Main (main) where

import Ratio

u :: Rational
u = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (take 3 (enumFrom (1 % 2 :: Rational)), take 3 (enumFromThen 0 (1 % 3 :: Rational)))
  print (enumFromTo 1 (5 % 2 :: Rational), enumFromThenTo 1 (3 % 2) (3 :: Rational), enumFromThenTo 3 2 (0 :: Rational))
  print ([1, 1.5 .. 3] :: [Float], [0.1, 0.2 .. 0.35] :: [Double], [3, 2 .. 1] :: [Double])
  print (take 1 (enumFromTo 1 u))
