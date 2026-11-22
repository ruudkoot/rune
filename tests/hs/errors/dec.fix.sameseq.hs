-- Report 4.4.2: a fixity declaration stands with its operator's declaration: not in a let for an outer one.
module Main (main) where

(+++) :: Int -> Int -> Int
a +++ b = a

x :: Int
x = let infixl 1 +++ in 1 +++ 2

main :: IO ()
main = return ()
