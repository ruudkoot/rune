-- Report: default () turns defaulting off: print (1 + 2) is ambiguous, rejected.
module Main where
default ()
main = print (1 + 2)
