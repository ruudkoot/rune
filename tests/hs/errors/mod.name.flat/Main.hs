-- Report 5: the module name space is flat, each module's name unique: two modules named A.
module Main (main) where

import A
import B

main :: IO ()
main = return ()
