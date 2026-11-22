-- Report 4.2.3: a newtype's record has one field: not C { a :: Int, b :: Int }.
module Main (main) where

newtype T = C { a :: Int, b :: Int }

main :: IO ()
main = return ()
