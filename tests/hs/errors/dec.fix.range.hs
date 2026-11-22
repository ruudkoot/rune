-- Report 4.4.2: the precedence is from 0 to 9: not 10.
module Main (main) where

infixl 10 +++
(+++) :: Int -> Int -> Int
a +++ b = a

main :: IO ()
main = return ()
