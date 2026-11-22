-- Report 4.2.1, 10: a data declaration's context constrains its constructor: T shown at a type with no Eq.
module Main (main) where

data Eq a => T a = T a deriving Show

x :: String
x = show (T id)

main :: IO ()
main = return ()
