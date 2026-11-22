-- Report 4.3.2: an instance type's arguments are type variables: not (Int, a).
module Main (main) where

class C a
instance C (Int, a)

main :: IO ()
main = return ()
