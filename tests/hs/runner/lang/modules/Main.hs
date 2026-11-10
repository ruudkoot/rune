-- A program of two modules in a directory (tests/runner/hslang.sml): its
-- siblings are tests/hs/runner/lang/modules.*, beside the directory.
module Main (main) where

import Greeting

main :: IO ()
main = greet
