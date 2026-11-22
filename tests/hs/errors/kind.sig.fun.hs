-- Report 4.6: the arguments of (->) have kind *: not Maybe -> Int.
module Main (main) where

f :: Maybe -> Int
f = undefined

main :: IO ()
main = return ()
