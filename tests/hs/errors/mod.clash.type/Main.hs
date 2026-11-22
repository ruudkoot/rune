-- Report 5.5.2: name resolution covers types: T from two modules in a signature.
module Main (main) where

import TA
import TB

f :: T -> Int
f _ = 0

main :: IO ()
main = return ()
