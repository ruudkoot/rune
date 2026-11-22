-- Report 4.3.2: a type is an instance of a class once in the program.
module Main (main) where

class C a
instance C Int
instance C Int

main :: IO ()
main = return ()
