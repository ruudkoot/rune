-- Report 4.3.1: the context is an scontext: not Eq (f a).
module Main (main) where

class Eq (f a) => C f

main :: IO ()
main = return ()
