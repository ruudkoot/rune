-- Report 3.5: a section's operand may hold operators that bind tighter: (a * b +) and (+ a * b).
module Main (main) where

main :: IO ()
main = print ((a * b +) 1, (+ a * b) 1)
  where
    a = 2 :: Int
    b = 3
