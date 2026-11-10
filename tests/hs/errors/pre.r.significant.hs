-- Report 8: only the Prelude's exports are significant: numericEnumFrom is not one.
module Main (main) where

x :: [Double]
x = numericEnumFrom 1
main :: IO ()
main = return ()
