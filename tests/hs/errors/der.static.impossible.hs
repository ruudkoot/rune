-- Report 10: a derived instance that cannot be made is a static error.
module Main (main) where

data T = T (Int -> Int) deriving (Show, Eq)

main :: IO ()
main = return ()
