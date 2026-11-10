-- Report 3.3: a lambda's patterns are apats, so no unparenthesised constructor application: \Just x -> x.
module Main (main) where

f :: Maybe Int -> Int
f = \Just x -> x

main :: IO ()
main = return ()
