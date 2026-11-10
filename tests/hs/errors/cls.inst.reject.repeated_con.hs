-- Report 4.3.2: an instance type's variables are distinct: not T a a.
module Main (main) where

data T a b = T
class C a
instance C (T a a)

main :: IO ()
main = return ()
