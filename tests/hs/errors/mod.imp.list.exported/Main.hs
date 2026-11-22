-- Report 5.3.1: an import list names what the module exports.
module Main (main) where

import A (z)

main :: IO ()
main = return ()
