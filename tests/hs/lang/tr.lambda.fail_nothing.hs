-- Report 3.3: a lambda's pattern that fails to match makes the result bottom.
module Main (main) where

main :: IO ()
main = print ((\(Just x) -> x) (Nothing :: Maybe Int))
