-- Report 4.3.2: an instance type's variables are distinct: not a -> a.
module Main (main) where

class C a
instance C (a -> a)

main :: IO ()
main = return ()
