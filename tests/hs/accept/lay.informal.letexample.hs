-- Report 2.7: in "f x = let a = 1; b = 2 / g y = exp2 / in exp1", a, b and g are one layout list (the Report's
-- example, its exp1 and exp2 written out).
module Main (main) where

f :: Int -> Int
f x = let a = 1; b = 2
          g y = y + a
      in g b + x

main :: IO ()
main = print (f 1)
