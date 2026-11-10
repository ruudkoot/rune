-- Report 4.6: an unconstrained class variable defaults to *: not C Maybe.
module Main (main) where

class C a

instance C Maybe

main :: IO ()
main = return ()
