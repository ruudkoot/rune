-- rows: der.enum.lexeme
-- Report 2.4: `F..` is the operator `.` qualified by `F`, so `[False..]` is no enumeration but that operator, of a
-- module False that is not there (`[False ..]` is the sequence).
module Main (main) where

main :: IO ()
main = print [False..]
