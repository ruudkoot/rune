-- Report 4.4.3: an operand of an infix definition at a lower precedence than its operator is refused
-- unparenthesised: with infixl 9 +++, not a :+ b +++ c.
module Main (main) where

infixl 9 +++
infixl 5 :+
data P = Int :+ Int
(+++) :: P -> Int -> Int
a :+ b +++ c = a

main :: IO ()
main = return ()
