-- Report 4.1.4: a type is an instance of a class only by an instance declaration or a deriving clause.
module Main (main) where

data T = T

x :: Bool
x = T == T

main :: IO ()
main = return ()
