-- rows: mod.exp.distinct.same mod.exp.distinct.valid mod.exp.distinct.namespace
-- Report 5.2: export lists are cumulative, so repetitions are harmless; one entity by two routes is no clash; a type T and
-- a constructor T exported together are in two name spaces.
module Main (main) where

import M

main :: IO ()
main = print (x, case T of T -> 0)
