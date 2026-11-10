-- rows: R72
-- Report 5.2: the subordinate names of T(c1,...,cn) are unqualified: not T(N.c).
module Main (main, T(Main.C)) where

data T = C

main :: IO ()
main = return ()
