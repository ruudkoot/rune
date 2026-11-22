-- Report 4.5.4: a lambda's variables are monomorphic: f at Int and Char.
module Main (main) where

g = \f -> (f 1, f 'c')

main :: IO ()
main = return ()
