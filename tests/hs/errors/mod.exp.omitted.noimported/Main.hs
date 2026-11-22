-- Report 5.2: with no export list what a module imports is not exported.
module Main (main) where

import M

main :: IO ()
main = print y
