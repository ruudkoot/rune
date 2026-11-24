-- Report: read of Int follows the Report's lexer for decimal digits (readDec); GHC's Read Int accepts 0x.
module Main where
main = print ((reads :: ReadS Int) "0x10")
