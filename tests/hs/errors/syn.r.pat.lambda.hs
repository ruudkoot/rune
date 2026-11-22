-- Report 9.5: exp10 -> \ apat1 ... apatn -> exp: a lambda's patterns are apats, so x:xs needs its parentheses.
module Main (main) where

main :: IO ()
main = print ((\x:xs -> x) [1])
