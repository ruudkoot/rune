-- Report 23 (the lead's ruling 33, implementation-defined): getProgName is the program file's base name without its
-- extension: the runner compiles each program to prog.rbc (Lang.suite's binary), so it is prog.
module Main (main) where

import System

main :: IO ()
main = getProgName >>= putStrLn . filter (/= '\n')
