-- Report 2.6: a character literal holds exactly one character: `''` is none.
module Main (main) where

c :: Char
c = ''

main :: IO ()
main = return ()
