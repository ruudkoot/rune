-- Report 5.3.1: hiding imports all but what it names.
module Main (main) where

import A hiding (x)

main :: IO ()
main = print x
