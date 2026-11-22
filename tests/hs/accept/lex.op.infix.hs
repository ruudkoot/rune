-- Report 2.4: "Other than the special syntax for prefix negation, all operators are infix, although each infix operator
-- can be used in a section": an operator of the program, infix and in both sections.
module Main (main) where

(<+>) :: Int -> Int -> Int
a <+> b = a * 10 + b

main :: IO ()
main = print (1 <+> 2, (1 <+>) 2, (<+> 2) 1, (<+>) 1 2)
