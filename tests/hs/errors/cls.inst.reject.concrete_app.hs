-- Report 4.3.2: an instance type's arguments are type variables: not Maybe Int.
module Main (main) where

class C a
instance C (Maybe Int)

main :: IO ()
main = return ()
