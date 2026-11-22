-- Report 3, 4.4.2: one precedence, one left and one right associative operator, unparenthesised: a syntax error.
module Main (main) where

infixl 5 +++
infixr 5 ***
(+++), (***) :: Int -> Int -> Int
a +++ b = a + b
a *** b = a * b

main :: IO ()
main = print (1 +++ 2 *** 3)
