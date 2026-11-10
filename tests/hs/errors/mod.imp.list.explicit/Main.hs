-- Report 5.3.1: an import list brings in what it names and no more.
module Main (main) where

import A (x)

main :: IO ()
main = print y
