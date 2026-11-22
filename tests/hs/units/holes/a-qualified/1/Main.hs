module Main where

import qualified M as Q

f :: Int
f = 10

main :: IO ()
main = print (Q.f + f)
