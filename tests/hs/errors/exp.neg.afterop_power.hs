-- Report 3.4: negation does not directly follow an operator of precedence 6 or more: not a ^ - b.
module Main (main) where

main :: IO ()
main = print (2 ^ - 3)
