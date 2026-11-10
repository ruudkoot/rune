-- Report 4.3.4: topdecl -> default (type1 , ... , typen): two types.
module Main (main) where

default (Int, Double)

main :: IO ()
main = return ()
