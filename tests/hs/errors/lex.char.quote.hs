-- Report 2.6: char -> ' (graphic<' | \> | ...) ': a single quote must be escaped in a character.
module Main (main) where

c :: Char
c = '''

main :: IO ()
main = return ()
