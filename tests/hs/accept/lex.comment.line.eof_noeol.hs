-- rows: R4 deviation
-- Report 2.3 (R4, the owner's call of 2026-11-10): comment -> dashes [any<symbol> {any}] newline needs a newline, and
-- this file ends in a line comment with none: rhc takes the end of the file as ending it, a deviation from the grammar
-- taken literally (tests/hs/deviations.tsv), as GHC, Hugs and nhc98 accept it.
module Main (main) where

main :: IO ()
main = return ()
-- the last line: a line comment and no newline after it