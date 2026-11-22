-- Report 3: two non-associative operators of one precedence, unparenthesised: a == b == c.
module Main (main) where

main :: IO ()
main = print (True == True == True)
