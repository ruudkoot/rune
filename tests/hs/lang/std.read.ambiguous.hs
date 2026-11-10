-- Report 6.3.3: read fails where the parse is ambiguous: an instance with two parses.
module Main (main) where

data A = A deriving Show

instance Read A where
  readsPrec _ s = [(A, s), (A, s)]

main :: IO ()
main = print (read "" :: A)
