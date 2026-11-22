-- Report 5.2: module N in an export list needs an import of N.
module Main (main) where

import X

main :: IO ()
main = return ()
