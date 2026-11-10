-- Report 5.5.2: d reached through B and through C is one entity: d, B.d and C.d are it.
module Main (main) where

import B
import C

main :: IO ()
main = print (d == B.d && B.d == C.d, d)
