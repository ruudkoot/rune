module Main where

import M hiding (g)

g :: Int
g = 20

main :: IO ()
main = print (f + g)
