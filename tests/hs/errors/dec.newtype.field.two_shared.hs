-- Report 4.2.3: a newtype's record has one field: not C { a, b :: Int }.
module Main (main) where

newtype T = C { a, b :: Int }

main :: IO ()
main = return ()
