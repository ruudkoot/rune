-- Report 2.1: a non-ASCII character in a string literal, read from the UTF-8 source (readings.md R5), is its code point at
-- run time.
module Main (main) where

main :: IO ()
main = print (map fromEnum "éλ∀")
