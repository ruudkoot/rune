-- Report 4.1.4: the generalization preorder takes the context in: a -> a is not the type of x + x.
module Main (main) where

f :: a -> a
f x = x + x

main :: IO ()
main = return ()
