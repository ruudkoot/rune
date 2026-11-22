-- Report 9.5: funlhs -> pat(i+1) varop(a,i) pat(i+1): the arguments of an infix definition bind tighter than its
-- operator, so x : xs, of precedence 5, is no left argument of +++ at 9.
module Main (main) where

infixl 9 +++
(+++) :: [a] -> [a] -> [a]
x : xs +++ ys = x : (xs ++ ys)
_ +++ ys = ys

main :: IO ()
main = return ()
