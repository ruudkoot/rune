-- Report 4.1.1: kinds are implicit and no part of the syntax: not data T (f :: * -> *) = C.
module Main (main) where

data T (f :: * -> *) = C

main :: IO ()
main = return ()
