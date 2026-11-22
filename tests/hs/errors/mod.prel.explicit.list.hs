-- Report 5.6.1: an explicit import of the Prelude replaces the implicit one: import Prelude (map, print, IO, return).
module Main (main) where

import Prelude (map, print, IO, return)

main :: IO ()
main = print (filter even [1])
