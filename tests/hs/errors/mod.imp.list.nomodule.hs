-- Report 5.3.1: the module modid form is not permitted in an import list.
module Main (main) where

import Char (module Char)

main :: IO ()
main = return ()
