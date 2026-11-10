-- Report 2.6: char -> ' (graphic<' | \> | ...) ': a backslash must be escaped.
module Main (main) where

c :: Char
c = '\'

main :: IO ()
main = return ()
