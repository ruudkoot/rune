-- rows: R27
-- Report 4.3.3, 15.1: a class of a standard library may be derivable: Ix (R27: the only one the Report gives).
module Main (main) where

import Ix

data T = A | B | C deriving (Eq, Ord, Show, Ix)

main :: IO ()
main = print (range (A, C), index (A, C) B)
