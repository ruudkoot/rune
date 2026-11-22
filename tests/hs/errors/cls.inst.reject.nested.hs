-- Report 4.3.2: the arguments are simple: not [[a]].
module Main (main) where

class C a
instance C [[a]]

main :: IO ()
main = return ()
