-- Report 5.3.1: qualifiers are not permitted in an import list: not import M (M.x).
module Main (main) where

import Char (Char.ord)

main :: IO ()
main = return ()
