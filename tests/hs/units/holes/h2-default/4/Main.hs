-- H4: the default in the key: Main's own default edited, Integer first.
module Main where

import T
import I1 ()

default (Integer, MyNum)

main :: IO ()
main = print (succ 2 * 3)
