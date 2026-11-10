-- Report 10.2: toEnum past the last is an error.
module Main (main) where

data Color = Red | Orange | Yellow | Green deriving (Show, Eq, Enum, Bounded)

main :: IO ()
main = print (toEnum 4 :: Color)
