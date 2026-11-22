-- Report 4.2.1: the type variables of a data declaration are distinct.
module Main (main) where

data T a a = C a

main :: IO ()
main = return ()
