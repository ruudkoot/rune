-- Report 4.1.3: a class takes one argument: not C a b.
module Main (main) where

class C a
f :: C a b => a -> b
f = undefined

main :: IO ()
main = return ()
