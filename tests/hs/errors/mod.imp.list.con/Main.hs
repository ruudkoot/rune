-- Report 5.3.1: a name alone in an import list is a class or a type, not a data constructor.
module Main (main) where

import M (Con)

main :: IO ()
main = return ()
