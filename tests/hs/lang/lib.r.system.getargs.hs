-- Report 23: getArgs gives the program's arguments, as given. It waits for B's primitives for the process and its environment.
module Main (main) where

import System

main :: IO ()
main = getArgs >>= print
