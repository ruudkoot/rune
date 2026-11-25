-- Report: forall is an ordinary varid.  GHC: always reserved (bugs.rst).
module Main where
forall :: Int
forall = 3
main = print forall
