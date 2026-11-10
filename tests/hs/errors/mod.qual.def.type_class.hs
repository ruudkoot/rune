-- rows: R71
-- Report 5.5.1: nor in a class declaration: not class M.C a.
module Main (main) where

class Main.C a

main :: IO ()
main = return ()
