-- Report 9.5: lexp6 -> - exp7: a prefix minus is no operand of another: not - - a.
module Main (main) where

main :: IO ()
main = print (- - 3)
