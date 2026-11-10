-- rows: R25
-- Report 4.4.2: the precedence is the grammar's integer, any integer literal: 0x5 and 05.
module Main (main) where

infixl 0x5 +++
infixl 05 ***
(+++), (***) :: Int -> Int -> Int
a +++ b = a - b
a *** b = a * b

main :: IO ()
main = print (10 +++ 2 *** 3)
