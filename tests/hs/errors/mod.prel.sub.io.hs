-- Report 5.6.1: PreludeIO is not imported on its own.
module Main (main) where

import PreludeIO

main :: IO ()
main = return ()
