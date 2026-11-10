-- Report 9.3: newline, return, linefeed and formfeed all begin a line, so the lexeme after each is in column 1: here a
-- formfeed and a lone return end lines of declarations.
module Main (main) where

main :: IO ()
main = print (x + y)x :: Int
x = 1y :: Int
y = 2
