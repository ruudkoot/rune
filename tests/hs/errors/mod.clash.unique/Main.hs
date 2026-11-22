-- Report 5.5.2: a name mentioned resolves to one entity: y from B and C.
module Main (main) where

import B
import C

main :: IO ()
main = print y
