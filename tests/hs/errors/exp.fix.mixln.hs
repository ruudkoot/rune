-- Report 3, 4.4.2: one precedence, one left and one non-associative operator, unparenthesised: a syntax error.
module Main (main) where

infixl 4 +++
(+++) :: Bool -> Bool -> Bool
a +++ b = a || b

main :: IO ()
main = print (True +++ 1 == 1)
