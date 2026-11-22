-- Report 5.5.1: nor in a type declaration: not data M.T = C.
module Main (main) where

data Main.T = C

main :: IO ()
main = return ()
