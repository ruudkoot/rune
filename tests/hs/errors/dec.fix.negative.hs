-- Report 4.4.2: the precedence is an integer token, with no sign: not infixl -1.
module Main (main) where

infixl -1 +++
(+++) :: Int -> Int -> Int
a +++ b = a

main :: IO ()
main = return ()
