-- Report 5.3.1: an empty list imports nothing but instances.
module Main (main) where

import A ()

main :: IO ()
main = print x
