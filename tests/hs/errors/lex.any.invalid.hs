-- Report 2.2: "Characters not in the category ANY are not valid in Haskell programs and should result in a lexing
-- error": a raw U+0001 between lexemes.
module Main (main) where

main :: IO ()
main = return ()
