-- Report 3.17.2: using x of ~(x, Just y) matches the whole pattern: on (1, undefined) it diverges (3.17.3 (d)).
module Main (main) where

main :: IO ()
main = print ((\ ~(x, Just y) -> x) (1 :: Int, undefined :: Maybe Int))
