-- Report 4.3.2: the instance type has a type constructor at its head: not a.
module Main (main) where

class C a
instance C a

main :: IO ()
main = return ()
