-- rows: R21
-- Report 4.5.2: one context for every variable of a group makes a constraint on another's variable ambiguous
-- (R21(a): rhc follows the text, D32).
module Main (main) where

f x = const True (g x, x == x)
g y = const 0 (f True)

main :: IO ()
main = print (g 'c')
