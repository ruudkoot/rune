-- Report 15.1: Ix is derivable only for enumerations and single-constructor types.
module Main (main) where

import Ix

data T = A Int | B deriving (Eq, Ord, Ix)

main :: IO ()
main = return ()
