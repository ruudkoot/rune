-- Report 9.5: lexp6 -> - exp7: prefix minus is no operand of a tighter operator: not a * - b.
module Main (main) where

main :: IO ()
main = print (2 * - 3)
