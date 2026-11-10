-- Report 4.3.4: each type of default is an instance of Num: not Bool.
module Main (main) where

default (Bool)

main :: IO ()
main = return ()
