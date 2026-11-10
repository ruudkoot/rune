-- rows: R76
-- Report 5.3.1: a subordinate name in an import list is one the module exports.
module Main (main) where

import M (T(Hidden))

main :: IO ()
main = return ()
