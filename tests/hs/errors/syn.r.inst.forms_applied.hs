-- Report 9.5: inst has five forms, with type variables for arguments: not T Int.
module Main (main) where

data T a = T
class C a
instance C (T Int)

main :: IO ()
main = return ()
