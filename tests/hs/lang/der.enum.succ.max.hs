-- Report 10.2: succ of the last constructor is an error.
module Main (main) where

data Color = Red | Orange | Yellow | Green deriving (Show, Eq, Enum, Bounded)

main :: IO ()
main = print (succ Green)
