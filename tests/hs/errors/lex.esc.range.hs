-- rows: R8
-- Report 2.6 (R8; ruling 49 makes the row a refusal): a numeric escape "may be of arbitrary length" and the Report
-- sets no bound on its value, yet a Char is finite; rhc refuses an escape above maxBound :: Char, 0x10FFFF, as a
-- static error, R8's seed.
module Main (main) where

main :: IO ()
main = putStrLn "\1114112"
