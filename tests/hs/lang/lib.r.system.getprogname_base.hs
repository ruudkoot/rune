-- Report 23 (the lead's ruling 33, implementation-defined): getProgName is the program file's base name without its
-- extension. It waits for B's M18, which implements it, and for the runner's name of the compiled program.
module Main (main) where

import System

main :: IO ()
main = getProgName >>= putStrLn . filter (/= '\n')
