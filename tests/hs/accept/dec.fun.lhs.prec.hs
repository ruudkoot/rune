-- Report 4.4.3: the operands of an infix definition are patterns at its operator's precedence: with infixl 6 +++ and a
-- constructor :* at 7, a :* b +++ c = ... defines +++.
module Main (main) where

infixl 6 +++
data P = Int :* Int
infixl 7 :*

(+++) :: P -> Int -> Int
a :* b +++ c = a + b + c

main :: IO ()
main = print (1 :* 2 +++ 3)
