-- Report 3.11: a generator binds monomorphically.
module Main (main) where

p = [(f 1, f 'a') | f <- [id]]

main :: IO ()
main = return ()
