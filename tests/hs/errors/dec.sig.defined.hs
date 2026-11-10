-- Report 4.4.1: the declared type must be inferable for the definition.
module Main (main) where

f :: Int -> Bool
f x = x

main :: IO ()
main = return ()
