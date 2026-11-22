-- Report 4.3.3: "It is a static error if an instance cannot be derived": Enum of a constructor with a field.
module Main (main) where

data T = A Int deriving Enum

main :: IO ()
main = return ()
