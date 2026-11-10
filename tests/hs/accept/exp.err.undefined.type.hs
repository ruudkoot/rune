-- Report 3.1: undefined is at every type.
module Main (main) where

x :: Int
x = undefined

y :: Maybe Bool
y = undefined

z :: Char -> Char
z = undefined

main :: IO ()
main = return ()
