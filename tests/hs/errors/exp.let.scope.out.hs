-- Report 3.12: a let's bindings do not scope outside it.
module Main (main) where

z :: Int
z = (let x = 1 in x) + x

main :: IO ()
main = return ()
