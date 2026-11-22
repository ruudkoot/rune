-- Report 5.2: a method not listed is not exported.
module Main (main) where

import M

main :: IO ()
main = print (l2 mk)
