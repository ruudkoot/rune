-- Report 5.2: a data constructor is named only as a subordinate name: module M (C) names no type or class C.
module Main (main) where

import M

main :: IO ()
main = return ()
