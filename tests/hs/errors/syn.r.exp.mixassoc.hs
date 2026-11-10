-- Report 9.5, 4.4.2: a left and a right associative operator of one precedence do not mix unparenthesised.
module Main (main) where

infixl 6 +++
infixr 6 ***
(+++), (***) :: Int -> Int -> Int
a +++ b = a + b
a *** b = a * b

main :: IO ()
main = print (1 +++ 2 *** 3)
