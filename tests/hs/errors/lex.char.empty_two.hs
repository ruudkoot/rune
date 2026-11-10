-- Report 2.6: a character literal holds exactly one character: `'ab'` is two.
module Main (main) where

c :: Char
c = 'ab'

main :: IO ()
main = return ()
