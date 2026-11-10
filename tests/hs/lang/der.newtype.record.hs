-- Report 10.4: a newtype declared with a field shows in record syntax: with braces.
module Main (main) where

newtype Age = Age { unAge :: Int } deriving Show

main :: IO ()
main = print (elem '{' (show (Age 3)), elem '}' (show (Age 3)))
