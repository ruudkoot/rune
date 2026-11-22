-- Report 5.1: a module of only a body has the header `module Main (main) where`. A.hs is such a file, read for an
-- import of A: refused, and each diagnostic of A.hs said at A.hs, its assumed export's among them, not at this file.
module Main (main) where

import A

main :: IO ()
main = print x
