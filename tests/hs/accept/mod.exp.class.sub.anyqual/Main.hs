-- Report 5.2: a subordinate method in scope under a qualified name only.
module Main (main) where

import M

main :: IO ()
main = print (c True)
