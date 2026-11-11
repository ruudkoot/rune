-- rows: R6 deviation
-- Report 2.5 and 19 (R6; ruling 49 makes the row a refusal, ruling 56 a deviation): decimal is digit{digit} and digit
-- takes any uniDigit, but no clause gives a Unicode digit a value, and chapter 19 says digits outside ASCII are not
-- used to represent numbers. rhc refuses a numeric literal of Arabic-Indic digits, a deviation from 2.5's grammar on
-- the ground that the text contradicts itself (tests/hs/deviations.tsv), as GHC, Hugs, nhc98 and MicroHs all refuse
-- it; such a digit may still stand in an identifier.
module Main (main) where

x :: Int
x = ١٢

main :: IO ()
main = print x
