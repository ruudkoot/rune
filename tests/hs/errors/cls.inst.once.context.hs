-- Report 4.3.2: instances that differ only in context are the same instance.
module Main (main) where

class C a
instance C [a]
instance Eq a => C [a]

main :: IO ()
main = return ()
