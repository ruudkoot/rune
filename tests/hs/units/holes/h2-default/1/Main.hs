module Main where

import T
import I1 ()

default (MyNum, Integer)

main :: IO ()
main = print (succ 2 * 3)
