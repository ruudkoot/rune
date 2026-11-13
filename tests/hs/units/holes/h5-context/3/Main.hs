module Main where

import D
import U

data N = N

instance Show N where
  show _ = "N"

data F = F

main :: IO ()
main = print (T (U N F))
