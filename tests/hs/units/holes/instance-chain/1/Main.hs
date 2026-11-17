-- Orphan first, so that its unit is before A's whatever Mid imports.
module Main where

import Orphan
import A

main :: IO ()
main = putStrLn a
