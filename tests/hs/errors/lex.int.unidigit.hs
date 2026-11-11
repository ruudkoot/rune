-- rows: R6
-- Report 2.5 and 19 (R6; ruling 49 makes the row a refusal): decimal is digit{digit} and digit takes any uniDigit,
-- but chapter 19 says digits outside ASCII are not used to represent numbers. rhc takes chapter 19's side, as GHC
-- does: a numeric literal of Arabic-Indic digits is refused, though such a digit may stand in an identifier.
module Main (main) where

x :: Int
x = ١٢

main :: IO ()
main = print x
