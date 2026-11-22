-- rows: R43 R82
-- Report 8.2 with the erratum of February 2003 (readings.md R82): an identifier may begin with an underscore: lex "_a".
module Main (main) where

main :: IO ()
main = print (lex "_a b", lex "_")
