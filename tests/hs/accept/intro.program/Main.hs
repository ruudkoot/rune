-- Report 1.1: a program is modules, one of them Main: two modules compile and link.
module Main (main) where

import A

main :: IO ()
main = print a
