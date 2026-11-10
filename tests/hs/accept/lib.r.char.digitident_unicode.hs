-- Report 19: numeric digits may be part of identifiers: x١ (ARABIC-INDIC DIGIT ONE) is a variable.
module Main (main) where

x١ :: Int
x١ = 1

y१z :: Int -> Int
y१z n = n + x١

main :: IO ()
main = print (y१z x١)
