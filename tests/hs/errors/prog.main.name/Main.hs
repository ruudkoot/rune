-- Report 5: a program has a module called Main: the main module of this one is called Main, and its main
-- module imports none of the two: here Main is the file, and it is no module Main.
module Program (main) where

main :: IO ()
main = return ()
