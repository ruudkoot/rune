-- Report 2.4: a qualified name is one lexeme, so with spaces `M . x` is three: the constructor M composed with x.
module Main (main) where

data T = M Int deriving Show

main :: IO ()
main = print ((M . negate) 1)
