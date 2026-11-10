-- Report 10.2: toEnum (-1) is an error.
module Main (main) where

data Color = Red | Orange | Yellow | Green deriving (Show, Eq, Enum, Bounded)

main :: IO ()
main = print (toEnum (-1) :: Color)
