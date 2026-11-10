-- Report 4.3.2: the type is an instance of each superclass: Eq T is missing.
module Main (main) where

class Eq a => C a
data T = T
instance C T

main :: IO ()
main = return ()
