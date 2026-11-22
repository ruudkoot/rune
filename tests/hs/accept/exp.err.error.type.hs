-- Report 3.1: error is at every type: used at several result types.
module Main (main) where

x :: Int
x = error "a"

y :: Bool
y = error "b"

z :: [Char] -> Char
z = error "c"

main :: IO ()
main = return ()
