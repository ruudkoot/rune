-- Report 9.5: lexp6 -> - exp7 at level 6: prefix minus is no right operand of + either: not a + - b.
module Main (main) where

main :: IO ()
main = print (2 + - 3)
