-- Report 4.6: the default makes App's second argument of kind *: not App Maybe Maybe.
module Main (main) where

data App f a = A (f a)

x :: App Maybe Maybe
x = undefined

main :: IO ()
main = return ()
