-- Report 4.3.1: the context is an scontext, its assertions on bare variables: not Eq [a].
module Main (main) where

class Eq [a] => C a

main :: IO ()
main = return ()
