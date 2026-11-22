-- Report 4.4.2: one fixity declaration for an operator, even if the same.
module Main (main) where

infixl 6 +++
infixl 6 +++
(+++) :: Int -> Int -> Int
a +++ b = a

main :: IO ()
main = return ()
