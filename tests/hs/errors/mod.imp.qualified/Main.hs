-- Report 5.3.2: a qualified import brings in the qualified names alone.
module Main (main) where

import qualified A

main :: IO ()
main = print x
