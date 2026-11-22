-- Report 2.6: char -> ' (... | escape<\&>) ': the null escape \& is no character.
module Main (main) where

c :: Char
c = '\&'

main :: IO ()
main = return ()
