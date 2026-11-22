-- Report 10.2: pred of the first is an error.
module Main (main) where

data Color = Red | Orange | Yellow | Green deriving (Show, Eq, Enum, Bounded)

main :: IO ()
main = print (pred Red)
