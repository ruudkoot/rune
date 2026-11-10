-- Report 4.3.2, 4.1.3: the context's variables are the instance type's.
module Main (main) where

class C a
instance Eq b => C [a]

main :: IO ()
main = return ()
