-- Report 5.2: with no export list everything the module defines is exported, each kind.
module Main (main) where

import M

main :: IO ()
main = print (x, m T, C 1 == C 1, (C 2 :: T2) /= C 3)
