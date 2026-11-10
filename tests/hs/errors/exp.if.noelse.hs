-- Report 3.6: exp -> if exp1 then exp2 else exp3: the else is not optional.
module Main (main) where

main :: IO ()
main = if True then return ()
