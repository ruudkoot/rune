-- Report 4.1.1: kind inference checks the validity of type expressions: Int takes no argument.
module Main (main) where

x :: Int Int
x = undefined

main :: IO ()
main = return ()
