-- Report 4.2.2: a synonym is no instance type.
module Main (main) where

type S = Int
class C a
instance C S

main :: IO ()
main = return ()
